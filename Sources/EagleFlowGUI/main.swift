import SwiftUI
import AppKit

/// Haupt-Einstiegspunkt der EagleFlow GUI-App
@main
struct EagleFlowGUIApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 800, minHeight: 600)
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
            
            CommandGroup(before: .help) {
                Button("Über EagleFlow") {
                    showAboutPanel()
                }
            }
        }
    }
    
    /// Initialisiert die App-Einstellungen
    private func setupApp() {
        NSWindow.allowsAutomaticWindowTabbing = false
    }
    
    /// Zeigt den Über-Dialog an
    private func showAboutPanel() {
        let appInfo = Bundle.main.infoDictionary ?? [:]
        let appName = "EagleFlow"
        let appVersion = appInfo["CFBundleShortVersionString"] as? String ?? "1.0.0"
        let buildNumber = appInfo["CFBundleVersion"] as? String ?? "1"
        
        let aboutPanel = NSAlert()
        aboutPanel.messageText = appName
        aboutPanel.informativeText = """
        Version \(appVersion) (Build \(buildNumber))
        
        EagleFlow ist ein MCP-Server für die Bereitstellung von PDF-Dokumenten
        für Claude und andere MCP-fähige KI-Assistenten.
        """
        aboutPanel.addButton(withTitle: "OK")
        
        aboutPanel.runModal()
    }
}