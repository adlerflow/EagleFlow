import Foundation
import MCP
import Logging

/// Ein MCP-Server für PDFs, der lokale PDF-Dokumente als Ressourcen bereitstellt
public class EagleFlowServer {
    /// Der zugrunde liegende MCP-Server
    private let server: Server
    
    /// Logger für Debugging
    private let logger: Logger
    
    /// Sammlung der verfügbaren PDF-Dokumente als Ressourcen
    private var resources: [Resource] = []
    
    /// Speichert die Zuordnung von Ressourcen-URIs zu tatsächlichen Dateipfaden
    private var resourcePathMap: [String: String] = [:]
    
    /// Flag, das angibt, ob der Server läuft
    public var isRunning: Bool {
        return server.isRunning
    }
    
    /// Name des Servers
    public let name: String
    
    /// Version des Servers
    public let version: String
    
    /// Initialisiere einen neuen EagleFlowServer mit Konfiguration
    /// - Parameters:
    ///   - name: Servername
    ///   - version: Serverversion
    ///   - logger: Optional Logger für Debugging
    public init(name: String = "EagleFlowServer", version: String = "1.0.0", logger: Logger? = nil) {
        self.name = name
        self.version = version
        self.logger = logger ?? Logger(label: "com.eagleflow.server")
        
        // Server mit Resource-Capabilities erstellen
        self.server = Server(
            name: name,
            version: version,
            capabilities: .init(
                resources: .init(
                    subscribe: true,
                    listChanged: true
                )
            ),
            logger: self.logger
        )
        
        // Handler registrieren
        self.registerHandlers()
    }
    
    /// Starte den Server mit dem angegebenen Transport
    /// - Parameter transport: Transport zur Kommunikation (z.B. HTTPServerTransport)
    /// - Returns: Keine Rückgabe, wirft einen Fehler bei Problemen
    public func start(transport: any Transport) async throws {
        logger.info("Starte EagleFlow Server (\(name) v\(version))...")
        
        try await server.start(transport: transport) { clientInfo, clientCapabilities in
            self.logger.info("Client verbunden: \(clientInfo.name) v\(clientInfo.version)")
            
            // Prüfe, ob der Client Resource-Fähigkeiten hat
            if clientCapabilities.resources == nil {
                self.logger.warning("Client unterstützt keine Resources, einige Funktionen werden nicht verfügbar sein")
            }
            
            // Wenn alles OK ist, erfolgreiche Initialisierung
            return
        }
        
        logger.info("Server gestartet und bereit für Verbindungen")
    }
    
    /// Stoppe den Server ordnungsgemäß
    public func stop() async {
        logger.info("Stoppe EagleFlow Server...")
        await server.stop()
        logger.info("Server gestoppt")
    }
    
    /// Füge ein lokales PDF-Dokument als Ressource hinzu
    /// - Parameters:
    ///   - path: Dateipfad zum PDF
    ///   - name: Optionaler Anzeigename (Standard: Dateiname)
    ///   - description: Optionale Beschreibung
    /// - Returns: Die hinzugefügte Ressource
    @discardableResult
    public func addPDFDocument(path: String, name: String? = nil, description: String? = nil) throws -> Resource {
        let url = URL(fileURLWithPath: path)
        let fileManager = FileManager.default
        
        // Prüfe, ob die Datei existiert
        guard fileManager.fileExists(atPath: path) else {
            logger.error("PDF nicht gefunden: \(path)")
            throw EagleFlowError.fileNotFound(path: path)
        }
        
        // Prüfe, ob es tatsächlich ein PDF ist (einfache Validierung)
        guard path.lowercased().hasSuffix(".pdf") else {
            logger.error("Datei scheint kein PDF zu sein: \(path)")
            throw EagleFlowError.invalidFileType(path: path)
        }
        
        let resourceName = name ?? url.deletingPathExtension().lastPathComponent
        let resourceDescription = description ?? "PDF-Dokument: \(url.lastPathComponent)"
        let resourceURI = "pdf://\(UUID().uuidString)"
        
        // Erstelle die Ressource
        let resource = Resource(
            uri: resourceURI,
            name: resourceName,
            description: resourceDescription,
            mimeType: "application/pdf"
        )
        
        // Speichere den tatsächlichen Pfad in einer privaten Map
        resourcePathMap[resourceURI] = path
        
        // Füge zur Ressourcenliste hinzu
        resources.append(resource)
        
        logger.info("PDF-Dokument hinzugefügt: '\(resourceName)' (URI: \(resourceURI))")
        
        // Sende Benachrichtigung über Ressourcenänderung, wenn der Server läuft
        if server.isRunning {
            try? await server.sendNotification(notification: ResourcesListChangedNotification.notification(.init()))
        }
        
        return resource
    }
    
    /// Entferne eine Ressource aus dem Server
    /// - Parameter uri: Die URI der zu entfernenden Ressource
    /// - Returns: true wenn erfolgreich, false wenn nicht gefunden
    @discardableResult
    public func removeResource(uri: String) async -> Bool {
        // Entferne aus der Ressourcenliste
        let initialCount = resources.count
        resources.removeAll { $0.uri == uri }
        
        // Wenn etwas entfernt wurde
        if resources.count < initialCount {
            // Entferne den Pfad aus der Map
            resourcePathMap.removeValue(forKey: uri)
            
            logger.info("Ressource entfernt: \(uri)")
            
            // Sende Benachrichtigung über Ressourcenänderung, wenn der Server läuft
            if server.isRunning {
                try? await server.sendNotification(notification: ResourcesListChangedNotification.notification(.init()))
            }
            
            return true
        }
        
        return false
    }
    
    /// Scanne ein Verzeichnis nach PDF-Dokumenten und füge sie als Ressourcen hinzu
    /// - Parameter directoryPath: Pfad zum zu scannenden Verzeichnis
    /// - Returns: Anzahl der gefundenen und hinzugefügten PDFs
    @discardableResult
    public func scanDirectoryForPDFs(directoryPath: String) throws -> Int {
        let fileManager = FileManager.default
        var isDirectory: ObjCBool = false
        
        // Expandiere Tilde im Pfad, falls vorhanden
        let expandedPath = (directoryPath as NSString).expandingTildeInPath
        
        // Prüfe, ob das Verzeichnis existiert
        guard fileManager.fileExists(atPath: expandedPath, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            logger.error("Verzeichnis nicht gefunden: \(expandedPath)")
            throw EagleFlowError.directoryNotFound(path: expandedPath)
        }
        
        // Durchlaufe das Verzeichnis und suche nach PDFs
        logger.info("Scanne Verzeichnis nach PDFs: \(expandedPath)")
        var addedCount = 0
        
        if let enumerator = fileManager.enumerator(atPath: expandedPath) {
            for case let file as String in enumerator {
                if file.lowercased().hasSuffix(".pdf") {
                    let fullPath = (expandedPath as NSString).appendingPathComponent(file)
                    do {
                        try addPDFDocument(path: fullPath)
                        addedCount += 1
                    } catch {
                        logger.warning("Fehler beim Hinzufügen von PDF \(fullPath): \(error.localizedDescription)")
                        // Fahre mit dem nächsten fort
                    }
                }
            }
        }
        
        logger.info("Scan abgeschlossen: \(addedCount) PDFs hinzugefügt")
        return addedCount
    }
    
    /// Gib alle aktuell verfügbaren Ressourcen zurück
    /// - Returns: Array von Resource-Objekten
    public func getResources() -> [Resource] {
        return resources
    }
    
    // MARK: - Private Implementierung
    
    /// Registriert alle Handler für den MCP-Server
    private func registerHandlers() {
        // Handler für resources/list
        server.withMethodHandler(ListResources.self) { [weak self] _ in
            guard let self = self else {
                return .init(resources: [], nextCursor: nil)
            }
            
            self.logger.debug("Methode aufgerufen: resources/list")
            return .init(resources: self.resources, nextCursor: nil)
        }
        
        // Handler für resources/read
        server.withMethodHandler(ReadResource.self) { [weak self] params in
            guard let self = self else {
                throw MCPError.internalError("Server nicht verfügbar")
            }
            
            let uri = params.uri
            self.logger.debug("Methode aufgerufen: resources/read mit URI: \(uri)")
            
            // Prüfe, ob wir den Pfad für diese URI haben
            guard let filePath = self.resourcePathMap[uri] else {
                self.logger.warning("Ressource nicht gefunden: \(uri)")
                throw MCPError.invalidParams("Ressource nicht gefunden: \(uri)")
            }
            
            do {
                // Lese die PDF-Datei als Binärdaten
                let data = try Data(contentsOf: URL(fileURLWithPath: filePath))
                
                self.logger.info("PDF-Ressource gelesen: \(uri) (\(data.count) Bytes)")
                
                // Gib die PDF-Daten zurück
                return .init(contents: [.init(uri: uri, mimeType: "application/pdf", blob: data)])
                
            } catch {
                self.logger.error("Fehler beim Lesen der PDF-Datei: \(error.localizedDescription)")
                throw MCPError.internalError("Fehler beim Lesen der PDF-Datei: \(error.localizedDescription)")
            }
        }
        
        // Handler für resources/subscribe
        server.withMethodHandler(SubscribeToResource.self) { [weak self] params in
            guard let self = self else {
                throw MCPError.internalError("Server nicht verfügbar")
            }
            
            let uri = params.uri
            self.logger.debug("Methode aufgerufen: resources/subscribe mit URI: \(uri)")
            
            // Prüfe, ob die Ressource existiert
            guard self.resourcePathMap[uri] != nil else {
                self.logger.warning("Ressource für Abonnement nicht gefunden: \(uri)")
                throw MCPError.invalidParams("Ressource nicht gefunden: \(uri)")
            }
            
            self.logger.info("Client hat Ressource abonniert: \(uri)")
            
            // Erfolgreiche Anmeldung
            return .init()
        }
    }
}

/// Fehlertypen für EagleFlow
public enum EagleFlowError: Error, LocalizedError {
    case fileNotFound(path: String)
    case invalidFileType(path: String)
    case directoryNotFound(path: String)
    case serverError(message: String)
    
    public var errorDescription: String? {
        switch self {
        case .fileNotFound(let path):
            return "Die Datei wurde nicht gefunden: \(path)"
        case .invalidFileType(let path):
            return "Die Datei ist kein unterstützter Typ: \(path)"
        case .directoryNotFound(let path):
            return "Das Verzeichnis wurde nicht gefunden: \(path)"
        case .serverError(let message):
            return "Serverfehler: \(message)"
        }
    }
}