import Foundation
import MCP
import NIO
import NIOHTTP1
import NIOExtras
import Logging

/// Ein Transport für MCP-Server über HTTP mit SSE (Server-Sent Events)
public class HTTPServerTransport: Transport {
    public nonisolated let logger: Logger
    
    private let host: String
    private let port: Int
    private let path: String
    
    private var group: EventLoopGroup?
    private var channel: Channel?
    private var isStarted = false
    
    private let messageQueue = AsyncQueue<Data>()
    private var connections: [ObjectIdentifier: SSEConnection] = [:]
    private let connectionLock = NSLock()
    
    /// Initialisiere einen neuen HTTP-Server-Transport
    /// - Parameters:
    ///   - host: Der Hostname oder die IP-Adresse, an dem der Server gebunden werden soll (Standard: localhost)
    ///   - port: Der Port, auf dem der Server lauschen soll (Standard: 8080)
    ///   - path: Der Pfad für den SSE-Endpunkt (Standard: /sse)
    ///   - logger: Ein optionaler Logger für Debug-Informationen
    public init(host: String = "localhost", port: Int = 8080, path: String = "/sse", logger: Logger? = nil) {
        self.host = host
        self.port = port
        self.path = path
        self.logger = logger ?? Logger(label: "com.eagleflow.http-transport")
    }
    
    public func connect() async throws {
        if isStarted {
            return
        }
        
        logger.info("Starte HTTP-Server auf \(host):\(port)\(path)")
        
        // NIO EventLoop initialisieren
        let group = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
        self.group = group
        
        // Server-Bootstrap konfigurieren
        let bootstrap = ServerBootstrap(group: group)
            .serverChannelOption(ChannelOptions.backlog, value: 256)
            .serverChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
            .childChannelInitializer { [weak self] channel in
                guard let self = self else {
                    return channel.eventLoop.makeFailedFuture(TransportError.notConnected)
                }
                
                let handler = HTTPHandler(
                    path: self.path,
                    onNewConnection: { [weak self] in self?.handleNewConnection($0) },
                    logger: self.logger
                )
                
                return channel.pipeline.configureHTTPServerPipeline().flatMap {
                    channel.pipeline.addHandler(handler)
                }
            }
            .childChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
            .childChannelOption(ChannelOptions.recvAllocator, value: AdaptiveRecvByteBufferAllocator())
        
        // Server starten
        do {
            channel = try await bootstrap.bind(host: host, port: port).get()
            if let localAddress = channel?.localAddress {
                logger.info("Server gestartet und lauscht auf \(localAddress)")
            }
            isStarted = true
        } catch {
            logger.error("Fehler beim Starten des HTTP-Servers: \(error)")
            throw error
        }
    }
    
    public func disconnect() async {
        logger.info("Stoppe HTTP-Server")
        
        // Verbindungen schließen
        connectionLock.lock()
        for (_, connection) in connections {
            connection.close()
        }
        connections.removeAll()
        connectionLock.unlock()
        
        // Channel und EventLoop-Gruppe beenden
        if let channel = channel {
            try? await channel.close().get()
            self.channel = nil
        }
        
        if let group = group {
            try? await group.shutdownGracefully()
            self.group = nil
        }
        
        isStarted = false
        logger.info("HTTP-Server gestoppt")
    }
    
    public func send(_ data: Data) async throws {
        guard isStarted else {
            throw TransportError.notConnected
        }
        
        logger.debug("Sende Nachricht an verbundene Clients (\(data.count) Bytes)")
        
        connectionLock.lock()
        let currentConnections = connections
        connectionLock.unlock()
        
        guard !currentConnections.isEmpty else {
            logger.warning("Keine aktiven Verbindungen zum Senden")
            return
        }
        
        for (_, connection) in currentConnections {
            connection.send(data)
        }
    }
    
    public func receive() -> AsyncThrowingStream<Data, Error> {
        return messageQueue.stream()
    }
    
    // Neue SSE-Verbindung verarbeiten
    private func handleNewConnection(_ connection: SSEConnection) {
        let id = ObjectIdentifier(connection)
        
        connectionLock.lock()
        connections[id] = connection
        connectionLock.unlock()
        
        connection.onMessage = { [weak self, weak connection] data in
            guard let self = self else { return }
            
            Task {
                await self.messageQueue.add(data)
            }
        }
        
        connection.onClose = { [weak self] in
            guard let self = self else { return }
            
            self.connectionLock.lock()
            self.connections.removeValue(forKey: id)
            self.connectionLock.unlock()
            
            self.logger.info("SSE-Verbindung geschlossen")
        }
        
        logger.info("Neue SSE-Verbindung registriert")
    }
}

/// Fehler im Zusammenhang mit dem Transport
enum TransportError: Error {
    case notConnected
    case invalidMessage
}

// MARK: - HTTP-Implementierung

/// AsyncQueue zum Thread-sicheren Empfangen von Nachrichten
actor AsyncQueue<T> {
    private var continuation: AsyncStream<T>.Continuation?
    private var buffer: [T] = []
    
    func add(_ value: T) {
        if let continuation = continuation {
            continuation.yield(value)
        } else {
            buffer.append(value)
        }
    }
    
    func stream() -> AsyncThrowingStream<T, Error> {
        return AsyncThrowingStream { continuation in
            Task {
                self.continuation = AsyncStream<T>.Continuation { 
                    continuation.finish() 
                }
                
                // Gepufferte Werte ausgeben
                for value in buffer {
                    continuation.yield(value)
                }
                buffer.removeAll()
            }
        }
    }
}

/// Vereinfachte SSE-Verbindung
class SSEConnection {
    let channel: Channel
    var onMessage: ((Data) -> Void)?
    var onClose: (() -> Void)?
    
    init(channel: Channel) {
        self.channel = channel
        
        channel.closeFuture.whenComplete { [weak self] _ in
            self?.onClose?()
        }
    }
    
    func send(_ data: Data) {
        var sseData = "data:"
        
        // Zeilenumbrüche im JSON berücksichtigen
        if let dataString = String(data: data, encoding: .utf8) {
            let lines = dataString.split(separator: "\n")
            for (i, line) in lines.enumerated() {
                if i > 0 {
                    sseData.append("\ndata:")
                }
                sseData.append(String(line))
            }
        } else {
            // Wenn String-Konvertierung fehlschlägt, rohe Binärdaten senden
            sseData.append(data.base64EncodedString())
        }
        
        sseData.append("\n\n") // Wichtig für SSE-Format
        
        guard let eventData = sseData.data(using: .utf8) else { return }
        var buffer = ByteBuffer(data: eventData)
        
        let _ = channel.writeAndFlush(HTTPServerResponsePart.body(.byteBuffer(buffer)))
    }
    
    func close() {
        _ = channel.close()
    }
}

/// Vereinfachter HTTP-Handler für NIO
final class HTTPHandler: ChannelInboundHandler {
    typealias InboundIn = HTTPServerRequestPart
    typealias OutboundOut = HTTPServerResponsePart
    
    private let path: String
    private let onNewConnection: (SSEConnection) -> Void
    private let logger: Logger
    private var pendingConnection: SSEConnection?
    private var pendingRequestBody: ByteBuffer?
    
    init(path: String, onNewConnection: @escaping (SSEConnection) -> Void, logger: Logger) {
        self.path = path
        self.onNewConnection = onNewConnection
        self.logger = logger
    }
    
    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let requestPart = unwrapInboundIn(data)
        
        switch requestPart {
        case .head(let request):
            if request.method == .GET && request.uri == path {
                handleSSERequest(context: context, request: request)
            } else if request.method == .POST {
                // Hier könnten wir MCP-Nachrichten vom Client verarbeiten
                pendingRequestBody = ByteBuffer()
            } else if request.method == .OPTIONS {
                handleCORSRequest(context: context, request: request)
            } else {
                // Standard-Info-Seite für andere Anfragen
                handleStaticRequest(context: context, request: request)
            }
            
        case .body(let buffer):
            if var body = pendingRequestBody {
                body.writeBuffer(&buffer)
                pendingRequestBody = body
            }
            
        case .end:
            if let connection = pendingConnection {
                // SSE-Verbindung registrieren
                onNewConnection(connection)
                pendingConnection = nil
                // Bei SSE senden wir kein .end, da die Verbindung offen bleibt
            } else if let body = pendingRequestBody {
                // Verarbeite POST-Anfragen (falls wir MCP-Nachrichten vom Client erhalten)
                pendingRequestBody = nil
                
                // Einfache OK-Antwort senden
                var headers = HTTPHeaders()
                headers.add(name: "Content-Type", value: "application/json")
                headers.add(name: "Content-Length", value: "2")
                
                let response = HTTPResponseHead(version: .init(major: 1, minor: 1), status: .ok, headers: headers)
                context.write(self.wrapOutboundOut(.head(response)), promise: nil)
                
                var responseBuffer = ByteBuffer()
                responseBuffer.writeString("{}")
                context.write(self.wrapOutboundOut(.body(.byteBuffer(responseBuffer))), promise: nil)
                context.write(self.wrapOutboundOut(.end(nil)), promise: nil)
                context.flush()
            } else {
                // Nichts zu tun für andere Anfragen
                context.flush()
            }
        }
    }
    
    private func handleSSERequest(context: ChannelHandlerContext, request: HTTPRequestHead) {
        // SSE-Header senden
        var headers = HTTPHeaders()
        headers.add(name: "Content-Type", value: "text/event-stream")
        headers.add(name: "Cache-Control", value: "no-cache")
        headers.add(name: "Connection", value: "keep-alive")
        headers.add(name: "Access-Control-Allow-Origin", value: "*")
        
        let response = HTTPResponseHead(version: request.version, status: .ok, headers: headers)
        context.write(self.wrapOutboundOut(.head(response)), promise: nil)
        context.flush()
        
        // SSE-Verbindung erstellen
        pendingConnection = SSEConnection(channel: context.channel)
        logger.info("SSE-Verbindung initialisiert")
    }
    
    private func handleCORSRequest(context: ChannelHandlerContext, request: HTTPRequestHead) {
        var headers = HTTPHeaders()
        headers.add(name: "Access-Control-Allow-Origin", value: "*")
        headers.add(name: "Access-Control-Allow-Methods", value: "GET, POST, OPTIONS")
        headers.add(name: "Access-Control-Allow-Headers", value: "Content-Type")
        headers.add(name: "Access-Control-Max-Age", value: "86400")
        
        let response = HTTPResponseHead(version: request.version, status: .noContent, headers: headers)
        context.write(self.wrapOutboundOut(.head(response)), promise: nil)
        context.write(self.wrapOutboundOut(.end(nil)), promise: nil)
        context.flush()
    }
    
    private func handleStaticRequest(context: ChannelHandlerContext, request: HTTPRequestHead) {
        let html = """
        <!DOCTYPE html>
        <html>
        <head>
            <title>EagleFlow MCP Server</title>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <style>
                body { font-family: -apple-system, BlinkMacSystemFont, sans-serif; max-width: 800px; margin: 40px auto; padding: 20px; line-height: 1.6; }
                h1 { color: #333; }
                .info { background-color: #f5f5f7; border-radius: 10px; padding: 20px; margin: 20px 0; }
                code { font-family: Menlo, Monaco, monospace; background-color: #eaeaea; padding: 2px 4px; border-radius: 3px; }
            </style>
        </head>
        <body>
            <h1>EagleFlow MCP Server</h1>
            <div class="info">
                <p>Dieser Server stellt PDF-Dokumente über das Model Context Protocol (MCP) bereit.</p>
                <p>MCP-Endpunkt: <code>\(path)</code></p>
                <p>Verbinde dich mit einem MCP-Client wie Claude Desktop, um auf die Dokumente zuzugreifen.</p>
            </div>
        </body>
        </html>
        """
        
        var headers = HTTPHeaders()
        headers.add(name: "Content-Type", value: "text/html; charset=UTF-8")
        headers.add(name: "Content-Length", value: "\(html.utf8.count)")
        
        let response = HTTPResponseHead(version: request.version, status: .ok, headers: headers)
        context.write(self.wrapOutboundOut(.head(response)), promise: nil)
        
        var buffer = ByteBuffer()
        buffer.writeString(html)
        context.write(self.wrapOutboundOut(.body(.byteBuffer(buffer))), promise: nil)
        context.write(self.wrapOutboundOut(.end(nil)), promise: nil)
        context.flush()
    }
    
    func channelReadComplete(context: ChannelHandlerContext) {
        context.flush()
    }
    
    func errorCaught(context: ChannelHandlerContext, error: Error) {
        logger.error("Fehler in HTTP-Handler: \(error)")
        context.close(promise: nil)
    }
}