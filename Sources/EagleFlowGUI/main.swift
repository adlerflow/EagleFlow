import SwiftUI
import AppKit
import EagleFlow
import EagleFlowUtils
import MCP
import Logging

@main
struct EagleFlowGUIApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 800, minHeight: 600)
                .onAppear {
                    NSWindow.allowsAutomaticWindowTabbing = false
                }
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("PDF hinzufügen...") {
                    NotificationCenter.default.post(name: .addPDF, object: nil)
                }
                .keyboardShortcut("n", modifiers: [.command])
            }
        }
    }
}

// Haupt-Content-View der App
struct ContentView: View {
    @StateObject private var viewModel = ServerViewModel()
    
    var body: some View {
        NavigationSplitView {
            Sidebar(viewModel: viewModel)
        } detail: {
            if viewModel.isServerRunning {
                ServerRunningView(viewModel: viewModel)
            } else {
                ServerSetupView(viewModel: viewModel)
            }
        }
        .navigationTitle("EagleFlow PDF Server")
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button(action: {
                    NSApp.sendAction(#selector(NSWindow.toggleToolbarShown(_:)), to: nil, from: nil)
                }) {
                    Image(systemName: "sidebar.left")
                }
            }
        }
        .onAppear {
            NotificationCenter.default.addObserver(forName: .addPDF, object: nil, queue: .main) { _ in
                viewModel.addPDFDocument()
            }
        }
    }
}

// Seitenleiste mit PDF-Liste
struct Sidebar: View {
    @ObservedObject var viewModel: ServerViewModel
    
    var body: some View {
        List {
            Section("Dokumente") {
                ForEach(viewModel.documents) { document in
                    HStack {
                        Image(systemName: "doc.text")
                            .foregroundColor(.blue)
                        Text(document.name)
                            .lineLimit(1)
                    }
                    .contextMenu {
                        Button("Entfernen") {
                            viewModel.removeDocument(document)
                        }
                    }
                }
                
                if viewModel.documents.isEmpty {
                    Text("Keine Dokumente")
                        .foregroundColor(.secondary)
                        .italic()
                }
            }
            
            Button("PDF hinzufügen...") {
                viewModel.addPDFDocument()
            }
            .buttonStyle(.plain)
            .padding(5)
            .frame(maxWidth: .infinity, alignment: .center)
            .background(Color.blue.opacity(0.1))
            .cornerRadius(5)
        }
        .listStyle(.sidebar)
        .frame(minWidth: 220)
    }
}

// Ansicht, wenn der Server noch nicht läuft
struct ServerSetupView: View {
    @ObservedObject var viewModel: ServerViewModel
    @State private var port = "8080"
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "server.rack")
                .font(.system(size: 60))
                .foregroundColor(.blue)
            
            Text("PDF-Server konfigurieren")
                .font(.title)
            
            VStack(alignment: .leading, spacing: 10) {
                Text("Füge PDF-Dokumente hinzu, die über MCP bereitgestellt werden sollen.")
                    .frame(maxWidth: 500)
                
                HStack {
                    Text("Server-Port:")
                    TextField("8080", text: $port)
                        .frame(width: 100)
                        .onSubmit {
                            if let portNum = Int(port), portNum > 0 && portNum < 65536 {
                                viewModel.port = portNum
                            } else {
                                port = "\(viewModel.port)"
                            }
                        }
                }
                .padding(.top)
            }
            .padding()
            .background(RoundedRectangle(cornerRadius: 8).fill(Color.secondary.opacity(0.1)))
            
            if viewModel.documents.isEmpty {
                Text("Hinweis: Es wurden noch keine PDF-Dokumente hinzugefügt.")
                    .foregroundColor(.orange)
                    .padding()
            }
            
            HStack(spacing: 20) {
                Button("Verzeichnis scannen...") {
                    viewModel.scanDirectory()
                }
                .buttonStyle(.bordered)
                
                Button("PDF hinzufügen...") {
                    viewModel.addPDFDocument()
                }
                .buttonStyle(.bordered)
                
                Button("Server starten") {
                    // Port aktualisieren
                    if let portNum = Int(port), portNum > 0 && portNum < 65536 {
                        viewModel.port = portNum
                    }
                    
                    // Server starten
                    viewModel.startServer()
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.documents.isEmpty)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// Ansicht, wenn der Server läuft
struct ServerRunningView: View {
    @ObservedObject var viewModel: ServerViewModel
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 60))
                .foregroundColor(.green)
            
            Text("Server läuft")
                .font(.title)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Server-Status:")
                    .bold()
                
                HStack {
                    Image(systemName: "circle.fill")
                        .foregroundColor(.green)
                        .font(.system(size: 10))
                    Text("Aktiv auf Port \(viewModel.port)")
                }
                
                Text("Endpunkte:")
                    .bold()
                    .padding(.top, 5)
                
                HStack {
                    Text("MCP-SSE:")
                    TextField("http://localhost:\(viewModel.port)/sse", text: .constant("http://localhost:\(viewModel.port)/sse"))
                        .textFieldStyle(.roundedBorder)
                        .disabled(true)
                    
                    Button(action: {
                        let pasteboard = NSPasteboard.general
                        pasteboard.clearContents()
                        pasteboard.setString("http://localhost:\(viewModel.port)/sse", forType: .string)
                    }) {
                        Image(systemName: "doc.on.doc")
                    }
                    .buttonStyle(.borderless)
                    .help("In Zwischenablage kopieren")
                }
                
                Text("Dokumente:")
                    .bold()
                    .padding(.top, 5)
                
                Text("\(viewModel.documents.count) PDF-Dokumente verfügbar")
            }
            .padding()
            .frame(maxWidth: 500)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color.secondary.opacity(0.1)))
            
            Divider()
                .padding()
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Claude Desktop Konfiguration:")
                    .bold()
                
                Text("Um die PDFs in Claude Desktop zu verwenden, füge folgende Konfiguration in die Claude Desktop Einstellungen ein:")
                    .fixedSize(horizontal: false, vertical: true)
                
                Text("""
                {
                  "mcpServers": {
                    "documentServer": {
                      "command": "npx",
                      "args": [
                        "mcp-remote",
                        "http://localhost:\(viewModel.port)/sse"
                      ]
                    }
                  }
                }
                """)
                .font(.system(.body, design: .monospaced))
                .padding()
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.black.opacity(0.05)))
                
                Button("Konfiguration kopieren") {
                    let config = """
                    {
                      "mcpServers": {
                        "documentServer": {
                          "command": "npx",
                          "args": [
                            "mcp-remote",
                            "http://localhost:\(viewModel.port)/sse"
                          ]
                        }
                      }
                    }
                    """
                    let pasteboard = NSPasteboard.general
                    pasteboard.clearContents()
                    pasteboard.setString(config, forType: .string)
                }
                .buttonStyle(.bordered)
            }
            .padding()
            .frame(maxWidth: 500)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color.blue.opacity(0.1)))
            
            Button("Server beenden") {
                viewModel.stopServer()
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
            .padding(.top)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// ViewModel für den Server-Status und die Dokumentenverwaltung
class ServerViewModel: ObservableObject {
    @Published var documents: [PDFDocument] = []
    @Published var isServerRunning = false
    @Published var port = 8080
    
    private var server: EagleFlowServer?
    private var serverTask: Task<Void, Error>?
    private let logger = Logger(label: "com.eagleflow.gui")
    
    // Fügt ein PDF-Dokument hinzu
    func addPDFDocument() {
        let openPanel = NSOpenPanel()
        openPanel.allowsMultipleSelection = true
        openPanel.canChooseDirectories = false
        openPanel.canChooseFiles = true
        openPanel.allowedContentTypes = [UTType.pdf]
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
    
    // Entfernt ein Dokument
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
    
    // Scannt ein Verzeichnis nach PDF-Dokumenten
    func scanDirectory() {
        let openPanel = NSOpenPanel()
        openPanel.allowsMultipleSelection = false
        openPanel.canChooseDirectories = true
        openPanel.canChooseFiles = false
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
    
    // Startet den Server
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
                let transport = HTTPServerTransport(port: port, logger: logger)
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
    
    // Stoppt den Server
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
    
    // Zeigt einen Fehler an
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

// Datenmodell für ein PDF-Dokument
struct PDFDocument: Identifiable {
    let id: String
    var name: String
    var uri: String
    var path: String
}

// Benachrichtigung für PDF-Hinzufügen
extension Notification.Name {
    static let addPDF = Notification.Name("addPDF")
}

// UTType-Erweiterung für PDF-Dateien
extension UTType {
    static let pdf = UTType(filenameExtension: "pdf")!
}