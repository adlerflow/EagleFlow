import SwiftUI

/// Haupt-Content-View der App
struct ContentView: View {
    @StateObject private var viewModel = ServerViewModel()
    
    // Ähnlich zu Food Truck: Statusverwaltung über StateObject
    @State private var selection: NavigationPanel = .overview
    @State private var path = NavigationPath()
    
    var body: some View {
        NavigationSplitView {
            // Sidebar mit PDF-Liste
            Sidebar(viewModel: viewModel, selection: $selection)
                .navigationTitle("EagleFlow")
        } detail: {
            NavigationStack(path: $path) {
                // Detail-Bereich basierend auf Auswahl
                switch selection {
                case .overview:
                    if viewModel.isServerRunning {
                        ServerRunningView(viewModel: viewModel)
                    } else {
                        ServerSetupView(viewModel: viewModel)
                    }
                case .documents:
                    DocumentsView(viewModel: viewModel)
                case .settings:
                    SettingsView(viewModel: viewModel)
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

/// Navigationspanels für die Seitenleiste
enum NavigationPanel: String, CaseIterable, Identifiable {
    case overview = "Übersicht"
    case documents = "Dokumente"
    case settings = "Einstellungen"
    
    var id: String { self.rawValue }
    
    var icon: String {
        switch self {
        case .overview: return "server.rack"
        case .documents: return "doc.text"
        case .settings: return "gear"
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