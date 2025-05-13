import Foundation
import SwiftUI
import EagleFlow
import EagleFlowUtils
import MCP
import Logging
import UniformTypeIdentifiers

/// ViewModel für den Server-Status und die Dokumentenverwaltung
class ServerViewModel: ObservableObject {
    /// Liste der PDF-Dokumente
    @Published var documents: [PDFDocument] = []
    
    /// Gibt an, ob der Server aktiv ist
    @Published var isServerRunning = false
    
    /// Der Port, auf dem der Server läuft
    @Published var port = 8080
    
    /// Der Hostname, auf dem der Server läuft
    @Published var host = "localhost"
    
    /// Der SSE-Pfad des Servers
    @Published var ssePath = "/sse"
    
    /// Die Server-Instanz
    private var server: EagleFlowServer?
    
    /// Die Server-Task, mit der der Server asynchron läuft
    private var serverTask: Task<Void, Error>?
    
    /// Logger für Protokollierung
    private let logger = Logger(label: "com.eagleflow.gui")
    
    /// Fügt ein PDF-Dokument hinzu
    func addPDFDocument() {
        let openPanel = NSOpenPanel()
        openPanel.allowsMultipleSelection = true
        openPanel.canChooseDirectories = false
        openPanel.canChooseFiles = true
        openPanel.allowedContentTypes = [UTType.pdf]
        openPanel.title = "PDF-Dokument auswählen"
        openPanel.prompt = "PDF hinzufügen"
        
        openPanel.begin { [weak self] response in
            guard let self = self, response == .OK else { return }
            
            for url in openPanel.urls {
                do {
                    if let server = self.server {
                        // Wenn der Server läuft, füge es dort hinzu
                        let resource = try server.addPDFDocument(path: url.path)
                        DispatchQueue.main.async {
                            self.documents.append(PDFDocument(id: UUID().uuidString, name: resource.name, uri: resource.uri, path: url.path))
                        }
                    } else {
                        // Sonst nur in der Liste speichern
                        let name = url.deletingPathExtension().lastPathComponent
                        DispatchQueue.main.async {
                            self.documents.append(PDFDocument(id: UUID().uuidString, name: name, uri: "", path: url.path))
                        }
                    }
                } catch {
                    self.showError("Fehler beim Hinzufügen", message: error.localizedDescription)
                }
            }
        }
    }
    
    /// Entfernt ein Dokument
    func removeDocument(_ document: PDFDocument) {
        if let server = server {
            Task {
                await server.removeResource(uri: document.uri)
                DispatchQueue.main.async {
                    self.documents.removeAll { $0.id == document.id }
                }
            }
        } else {
            documents.removeAll { $0.id == document.id }
        }
    }
    
    /// Scannt ein Verzeichnis nach PDF-Dokumenten
    func scanDirectory() {
        let openPanel = NSOpenPanel()
        openPanel.allowsMultipleSelection = false
        openPanel.canChooseDirectories = true
        openPanel.canChooseFiles = false
        openPanel.title = "Verzeichnis für PDF-Dokumente auswählen"
        openPanel.prompt = "Verzeichnis auswählen"
        
        openPanel.begin { [weak self] response in
            guard let self = self, response == .OK, let dirURL = openPanel.url else { return }
            
            let fileManager = FileManager.default
            
            if let server = self.server {
                // Wenn der Server bereits läuft
                do {
                    try server.scanDirectoryForPDFs(directoryPath: dirURL.path)
                    // Aktualisiere die UI-Liste aus dem Server
                    let resources = server.getResources()
                    DispatchQueue.main.async {
                        self.documents = resources.map { resource in
                            PDFDocument(id: UUID().uuidString, name: resource.name, uri: resource.uri, path: "")
                        }
                    }
                } catch {
                    self.showError("Scan-Fehler", message: error.localizedDescription)
                }
            } else {
                // Manuelles Scannen, wenn der Server noch nicht läuft
                do {
                    var newDocs: [PDFDocument] = []
                    let contents = try fileManager.contentsOfDirectory(atPath: dirURL.path)
                    
                    for file in contents where file.lowercased().hasSuffix(".pdf") {
                        let path = (dirURL.path as NSString).appendingPathComponent(file)
                        let name = (file as NSString).deletingPathExtension
                        let document = PDFDocument(id: UUID().uuidString, name: name, uri: "", path: path)
                        newDocs.append(document)
                    }
                    
                    DispatchQueue.main.async {
                        self.documents.append(contentsOf: newDocs)
                    }
                } catch {
                    self.showError("Scan-Fehler", message: error.localizedDescription)
                }
            }
        }
    }
    
    /// Startet den Server
    func startServer() {
        guard !isServerRunning, server == nil else { return }
        
        // Server erstellen
        let newServer = EagleFlowServer(name: "EagleFlowDocumentServer", version: "1.0.0", logger: logger)
        self.server = newServer
        
        // Dokumente hinzufügen
        for document in documents {
            if !document.path.isEmpty {
                do {
                    let resource = try newServer.addPDFDocument(path: document.path)
                    // URI aktualisieren
                    if let index = documents.firstIndex(where: { $0.id == document.id }) {
                        documents[index].uri = resource.uri
                    }
                } catch {
                    logger.error("Fehler beim Hinzufügen von \(document.name): \(error.localizedDescription)")
                }
            }
        }
        
        // Server starten
        serverTask = Task {
            do {
                let transport = HTTPServerTransport(host: host, port: port, path: ssePath, logger: logger)
                try await newServer.start(transport: transport)
                
                DispatchQueue.main.async {
                    self.isServerRunning = true
                }
            } catch {
                DispatchQueue.main.async {
                    self.server = nil
                    self.isServerRunning = false
                    self.showError("Server-Fehler", message: "Der Server konnte nicht gestartet werden: \(error.localizedDescription)")
                }
            }
        }
    }
    
    /// Stoppt den Server
    func stopServer() {
        guard isServerRunning, let server = server else { return }
        
        serverTask?.cancel()
        
        Task {
            await server.stop()
            
            DispatchQueue.main.async {
                self.server = nil
                self.isServerRunning = false
            }
        }
    }
    
    /// Zeigt einen Fehler an
    private func showError(_ title: String, message: String) {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = title
            alert.informativeText = message
            alert.alertStyle = .warning
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }
}