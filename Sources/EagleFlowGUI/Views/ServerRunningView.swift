import SwiftUI

/// Ansicht, wenn der Server läuft
struct ServerRunningView: View {
    @ObservedObject var viewModel: ServerViewModel
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 60))
                .foregroundColor(.green)
            
            Text("Server läuft")
                .font(.title)
            
            // Server-Statusbereich
            ServerStatusSection(viewModel: viewModel)
            
            Divider()
                .padding()
            
            // Claude Desktop Konfigurationsbereich
            ClaudeConfigSection(port: viewModel.port)
            
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

/// Anzeige des Server-Status
struct ServerStatusSection: View {
    @ObservedObject var viewModel: ServerViewModel
    
    var body: some View {
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
    }
}

/// Anzeige der Claude Desktop Konfiguration
struct ClaudeConfigSection: View {
    let port: Int
    @State private var configCopied = false
    
    var body: some View {
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
                    "http://localhost:\(port)/sse"
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
                        "http://localhost:\(port)/sse"
                      ]
                    }
                  }
                }
                """
                let pasteboard = NSPasteboard.general
                pasteboard.clearContents()
                pasteboard.setString(config, forType: .string)
                
                // Feedback anzeigen
                configCopied = true
                
                // Nach 2 Sekunden zurücksetzen
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    configCopied = false
                }
            }
            .buttonStyle(.bordered)
            
            if configCopied {
                Text("Konfiguration kopiert!")
                    .foregroundColor(.green)
                    .padding(.top, 2)
            }
        }
        .padding()
        .frame(maxWidth: 500)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.blue.opacity(0.1)))
    }
}