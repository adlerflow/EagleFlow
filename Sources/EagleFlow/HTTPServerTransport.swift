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
    
    private let messageContinuations = ContinuationStore<Data>()
    
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
        self.logger = logger ?? Logger(label: "com.eagleflow.http-server-transport")
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
            .childChannelInitializer { channel in
                let handler = HTTPHandler(messageContinuations: self.messageContinuations, path: self.path, logger: self.logger)
                return channel.pipeline.configureHTTPServerPipeline().flatMap {
                    channel.pipeline.addHandler(handler)
                }
            }
            .childChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
            .childChannelOption(ChannelOptions.maxMessagesPerRead, value: 16)
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
        
        if let channel = channel {
            try? await channel.close().get()
            self.channel = nil
        }
        
        if let group = group {
            try? await group.shutdownGracefully()
            self.group = nil
        }
        
        messageContinuations.cancelAll(with: CancellationError())
        isStarted = false
        
        logger.info("HTTP-Server gestoppt")
    }
    
    public func send(_ data: Data) async throws {
        guard isStarted else {
            throw TransportError.notConnected
        }
        
        logger.debug("Sende Nachricht an verbundene Clients (\(data.count) Bytes)")
        messageContinuations.yield(data, to: .all)
    }
    
    public func receive() -> AsyncThrowingStream<Data, Error> {
        return AsyncThrowingStream { continuation in
            let id = messageContinuations.register(continuation)
            continuation.onTermination = { [weak self] _ in
                self?.messageContinuations.remove(id)
            }
        }
    }
}

/// Fehler im Zusammenhang mit dem Transport
enum TransportError: Error {
    case notConnected
    case invalidMessage
}

/// HTTP-Handler für NIO, verarbeitet HTTP-Anfragen und managed SSE-Verbindungen
private final class HTTPHandler: ChannelInboundHandler {
    public typealias InboundIn = HTTPServerRequestPart
    public typealias OutboundOut = HTTPServerResponsePart
    
    private let messageContinuations: ContinuationStore<Data>
    private let path: String
    private let logger: Logger
    private var pendingResponse: HTTPResponseStatus?
    
    init(messageContinuations: ContinuationStore<Data>, path: String, logger: Logger) {
        self.messageContinuations = messageContinuations
        self.path = path
        self.logger = logger
    }
    
    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let requestPart = unwrapInboundIn(data)
        
        switch requestPart {
        case .head(let request):
            logger.debug("Anfrage empfangen: \(request.method) \(request.uri)")
            
            if request.method == .GET && request.uri == path {
                // SSE-Anfrage verarbeiten
                pendingResponse = .ok
                
                // SSE-Header senden
                var headers = HTTPHeaders()
                headers.add(name: "Content-Type", value: "text/event-stream")
                headers.add(name: "Cache-Control", value: "no-cache")
                headers.add(name: "Connection", value: "keep-alive")
                headers.add(name: "Access-Control-Allow-Origin", value: "*")
                
                let responseHead = HTTPResponseHead(version: request.version, status: .ok, headers: headers)
                context.write(self.wrapOutboundOut(.head(responseHead)), promise: nil)
                
                // Neue SSE-Verbindung registrieren
                registerSSEConnection(context: context)
            } else if request.method == .OPTIONS {
                // CORS Preflight-Anfrage beantworten
                handleOptionsRequest(context: context, request: request)
            } else if request.method == .POST {
                // POST-Anfrage für eingehende Nachrichten
                pendingResponse = .ok
                handlePostRequest(context: context, request: request)
            } else {
                // Seiten-HTML für andere Anfragen
                handleStaticRequest(context: context, request: request)
            }
            
        case .body(let byteBuffer):
            // Body-Daten verarbeiten, falls wir eine POST-Anfrage haben
            if pendingResponse == .ok && byteBuffer.readableBytes > 0 {
                let data = byteBuffer.getData(at: 0, length: byteBuffer.readableBytes) ?? Data()
                messageContinuations.yield(data, to: .all)
            }
            
        case .end:
            // Anfrage abschließen, falls nicht SSE
            if let status = pendingResponse, status != .ok {
                context.write(self.wrapOutboundOut(.end(nil)), promise: nil)
                context.flush()
            } else if pendingResponse == .ok {
                // POST-Anfrage mit 200 OK abschließen
                var headers = HTTPHeaders()
                headers.add(name: "Content-Type", value: "application/json")
                headers.add(name: "Content-Length", value: "2")
                
                let responseHead = HTTPResponseHead(version: .init(major: 1, minor: 1), status: .ok, headers: headers)
                context.write(self.wrapOutboundOut(.head(responseHead)), promise: nil)
                
                var buffer = context.channel.allocator.buffer(capacity: 2)
                buffer.writeString("{}")
                context.write(self.wrapOutboundOut(.body(.byteBuffer(buffer))), promise: nil)
                context.write(self.wrapOutboundOut(.end(nil)), promise: nil)
                context.flush()
            }
            pendingResponse = nil
        }
    }
    
    // Registriert eine neue SSE-Verbindung und richtet die Datenübermittlung ein
    private func registerSSEConnection(context: ChannelHandlerContext) {
        logger.info("Neue SSE-Verbindung registriert")
        
        let clientId = UUID().uuidString
        
        // Erstelle einen Task, der Daten vom ContinuationStore empfängt und an den Client sendet
        let task = Task {
            for await data in messageContinuations.stream(for: clientId) {
                guard !Task.isCancelled else { break }
                
                // SSE-Event formatieren
                var sseData = "data:"
                let dataString = String(data: data, encoding: .utf8) ?? ""
                let dataLines = dataString.split(separator: "\n")
                
                for (i, line) in dataLines.enumerated() {
                    if i > 0 {
                        sseData.append("\ndata:")
                    }
                    sseData.append(line)
                }
                sseData.append("\n\n")
                
                guard let eventData = sseData.data(using: .utf8) else {
                    continue
                }
                
                var buffer = context.channel.allocator.buffer(capacity: eventData.count)
                buffer.writeBytes(eventData)
                
                // Event an den Client senden
                context.writeAndFlush(self.wrapOutboundOut(.body(.byteBuffer(buffer))), promise: nil)
            }
        }
        
        // Bei Verbindungsabbruch aufräumen
        context.channel.closeFuture.whenComplete { [weak self] _ in
            task.cancel()
            self?.messageContinuations.remove(clientId)
            self?.logger.info("SSE-Verbindung geschlossen")
        }
    }
    
    // Behandelt eine OPTIONS-Anfrage für CORS-Preflight
    private func handleOptionsRequest(context: ChannelHandlerContext, request: HTTPRequestHead) {
        pendingResponse = .noContent
        
        var headers = HTTPHeaders()
        headers.add(name: "Access-Control-Allow-Origin", value: "*")
        headers.add(name: "Access-Control-Allow-Methods", value: "GET, POST, OPTIONS")
        headers.add(name: "Access-Control-Allow-Headers", value: "Content-Type")
        headers.add(name: "Access-Control-Max-Age", value: "86400")
        
        let responseHead = HTTPResponseHead(version: request.version, status: .noContent, headers: headers)
        context.write(self.wrapOutboundOut(.head(responseHead)), promise: nil)
    }
    
    // Behandelt eine POST-Anfrage (MCP-Nachricht)
    private func handlePostRequest(context: ChannelHandlerContext, request: HTTPRequestHead) {
        // POST wird im body case verarbeitet
    }
    
    // Sendet eine einfache HTML-Seite für andere Anfragen
    private func handleStaticRequest(context: ChannelHandlerContext, request: HTTPRequestHead) {
        pendingResponse = .ok
        
        let responseHTML = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>EagleFlow MCP Server</title>
            <style>
                body { font-family: system-ui, -apple-system, sans-serif; max-width: 800px; margin: 0 auto; padding: 20px; line-height: 1.6; }
                h1 { color: #333; }
                .info { background-color: #f0f0f0; padding: 15px; border-radius: 5px; margin: 20px 0; }
                .endpoint { font-family: monospace; background-color: #e0e0e0; padding: 5px; border-radius: 3px; }
            </style>
        </head>
        <body>
            <h1>EagleFlow MCP Server</h1>
            <div class="info">
                <p>Dieser Server stellt PDF-Dokumente als MCP-Ressourcen bereit.</p>
                <p>MCP-SSE-Endpunkt: <span class="endpoint">\(path)</span></p>
                <p>Verbinde dich mit einem MCP-Client wie Claude Desktop, um auf die PDFs zuzugreifen.</p>
            </div>
        </body>
        </html>
        """
        
        var headers = HTTPHeaders()
        headers.add(name: "Content-Type", value: "text/html; charset=UTF-8")
        headers.add(name: "Content-Length", value: "\(responseHTML.utf8.count)")
        headers.add(name: "Connection", value: "close")
        
        let responseHead = HTTPResponseHead(version: request.version, status: .ok, headers: headers)
        context.write(self.wrapOutboundOut(.head(responseHead)), promise: nil)
        
        var buffer = context.channel.allocator.buffer(capacity: responseHTML.utf8.count)
        buffer.writeString(responseHTML)
        context.write(self.wrapOutboundOut(.body(.byteBuffer(buffer))), promise: nil)
    }
}

/// Store für asynchrone Continuations, ermöglicht das Senden von Daten an mehrere Empfänger
internal class ContinuationStore<T> {
    private var continuations: [String: CheckedContinuation<T, Error>] = [:]
    private var streams: [String: AsyncStream<T>.Continuation] = [:]
    private let lock = NSLock()
    
    func register(_ continuation: CheckedContinuation<T, Error>) -> String {
        let id = UUID().uuidString
        lock.lock()
        defer { lock.unlock() }
        continuations[id] = continuation
        return id
    }
    
    func remove(_ id: String) {
        lock.lock()
        defer { lock.unlock() }
        continuations.removeValue(forKey: id)
        
        if let stream = streams.removeValue(forKey: id) {
            stream.finish()
        }
    }
    
    func yield(_ value: T, to target: YieldTarget) {
        lock.lock()
        defer { lock.unlock() }
        
        switch target {
        case .all:
            // An alle Continuations senden
            for (_, continuation) in continuations {
                continuation.resume(returning: value)
            }
            
            // An alle Streams senden
            for (_, stream) in streams {
                stream.yield(value)
            }
            
        case .id(let id):
            // An eine spezifische Continuation senden
            if let continuation = continuations[id] {
                continuation.resume(returning: value)
            }
            
            // An einen spezifischen Stream senden
            streams[id]?.yield(value)
        }
    }
    
    func cancelAll(with error: Error) {
        lock.lock()
        defer { lock.unlock() }
        
        // Alle Continuations abbrechen
        for (_, continuation) in continuations {
            continuation.resume(throwing: error)
        }
        continuations.removeAll()
        
        // Alle Streams beenden
        for (_, stream) in streams {
            stream.finish()
        }
        streams.removeAll()
    }
    
    func stream(for id: String) -> AsyncStream<T> {
        return AsyncStream { continuation in
            lock.lock()
            streams[id] = continuation
            lock.unlock()
            
            continuation.onTermination = { [weak self] _ in
                self?.lock.lock()
                self?.streams.removeValue(forKey: id)
                self?.lock.unlock()
            }
        }
    }
    
    enum YieldTarget {
        case all
        case id(String)
    }
}