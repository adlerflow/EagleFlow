import SwiftUI

/// Haupt-Content-View der App
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
            
            if viewModel.isServerRunning {
                ToolbarItem(placement: .automatic) {
                    HStack {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 8, height: 8)
                        Text("Server aktiv")
                            .font(.caption)
                    }
                }
            }
        }
        .onAppear {
            setupNotifications()
        }
    }
    
    /// Richtet Benachrichtigungen ein
    private func setupNotifications() {
        NotificationCenter.default.addObserver(forName: .addPDF, object: nil, queue: .main) { _ in
            viewModel.addPDFDocument()
        }
    }
}

/// Benachrichtigung für PDF-Hinzufügen
extension Notification.Name {
    static let addPDF = Notification.Name("addPDF")
}

/// UTType-Erweiterung für PDF-Dateien
extension UTType {
    static let pdf = UTType(filenameExtension: "pdf")!
}