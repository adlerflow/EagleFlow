import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: ServerViewModel
    @State private var port = ""
    @State private var host = ""
    @State private var ssePath = ""
    
    var body: some View {
        Form {
            Section("Server-Einstellungen") {
                HStack {
                    Text("Hostname:")
                    TextField("localhost", text: $host)
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: host) { newValue in
                            if !viewModel.isServerRunning {
                                viewModel.host = newValue
                            }
                        }
                }
                
                HStack {
                    Text("Port:")
                    TextField("8080", text: $port)
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: port) { newValue in
                            if let portNum = Int(newValue), portNum > 0 && portNum < 65536 && !viewModel.isServerRunning {
                                viewModel.port = portNum
                            }
                        }
                }
                
                HStack {
                    Text("SSE-Pfad:")
                    TextField("/sse", text: $ssePath)
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: ssePath) { newValue in
                            if !viewModel.isServerRunning {
                                viewModel.ssePath = newValue
                            }
                        }
                }
            }
            .disabled(viewModel.isServerRunning)
            
            Section {
                if viewModel.isServerRunning {
                    Button("Server neustarten") {
                        Task {
                            viewModel.stopServer()
                            // Kurz warten
                            try? await Task.sleep(nanoseconds: 1_000_000_000)
                            viewModel.startServer()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    Button("Server starten") {
                        viewModel.startServer()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            
            Section("Integration mit Claude Desktop") {
                Text("Kopiere die folgende Konfiguration in die Claude Desktop Einstellungen")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("""
                {
                  "mcpServers": {
                    "documentServer": {
                      "command": "npx",
                      "args": [
                        "mcp-remote",
                        "http://\(viewModel.host):\(viewModel.port)\(viewModel.ssePath)"
                      ]
                    }
                  }
                }
                """)
                .font(.system(.body, design: .monospaced))
                .padding(8)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(8)
                
                Button("Konfiguration kopieren") {
                    let config = """
                    {
                      "mcpServers": {
                        "documentServer": {
                          "command": "npx",
                          "args": [
                            "mcp-remote",
                            "http://\(viewModel.host):\(viewModel.port)\(viewModel.ssePath)"
                          ]
                        }
                      }
                    }
                    """
                    let pasteboard = NSPasteboard.general
                    pasteboard.clearContents()
                    pasteboard.setString(config, forType: .string)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .navigationTitle("Einstellungen")
        .onAppear {
            // Initialisiere die Formularfelder
            port = "\(viewModel.port)"
            host = viewModel.host
            ssePath = viewModel.ssePath
        }
    }
}