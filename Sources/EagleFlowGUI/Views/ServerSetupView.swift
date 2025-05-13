import SwiftUI

/// Ansicht, wenn der Server noch nicht läuft
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