import SwiftUI

@main
struct EagleFlowGUIApp: App {
    @StateObject private var viewModel = ServerViewModel()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 800, minHeight: 600)
                .environmentObject(viewModel)
                .onAppear {
                    setupApp()
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
        
        #if os(macOS)
        .defaultSize(width: 1000, height: 650)
        
        // MenuBarExtra für schnellen Zugriff wie im Food Truck Sample
        MenuBarExtra {
            VStack(spacing: 8) {
                if viewModel.isServerRunning {
                    HStack {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 8, height: 8)
                        Text("Server aktiv auf Port \(viewModel.port)")
                    }
                    .padding(.bottom, 4)
                    
                    Divider()
                    
                    Button("Neues PDF hinzufügen") {
                        viewModel.addPDFDocument()
                    }
                    
                    if !viewModel.documents.isEmpty {
                        Text("\(viewModel.documents.count) Dokumente verfügbar")
                            .font(.caption)
                    }
                    
                    Divider()
                    
                    Button(viewModel.isServerRunning ? "Server stoppen" : "Server starten") {
                        if viewModel.isServerRunning {
                            viewModel.stopServer()
                        } else {
                            viewModel.startServer()
                        }
                    }
                } else {
                    Text("Server ist gestoppt")
                    Button("Server starten") {
                        viewModel.startServer()
                    }
                }
            }
            .padding()
            .frame(width: 240)
        } label: {
            Label("EagleFlow", systemImage: "doc.viewfinder")
        }
        .menuBarExtraStyle(.window)
        #endif
    }
    
    private func setupApp() {
        NSWindow.allowsAutomaticWindowTabbing = false
    }
}