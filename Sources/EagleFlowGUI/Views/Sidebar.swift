import SwiftUI

/// Seitenleiste mit PDF-Liste
struct Sidebar: View {
    @ObservedObject var viewModel: ServerViewModel
    @Binding var selection: NavigationPanel
    
    var body: some View {
        List(selection: $selection) {
            Section("Server") {
                NavigationLink(value: NavigationPanel.overview) {
                    Label("Übersicht", systemImage: NavigationPanel.overview.icon)
                }
            }
            
            Section("Dokumente") {
                NavigationLink(value: NavigationPanel.documents) {
                    Label("PDF-Sammlung", systemImage: NavigationPanel.documents.icon)
                }
                
                // PDF-Dokumente anzeigen
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
                
                Button("PDF hinzufügen...") {
                    viewModel.addPDFDocument()
                }
                .buttonStyle(.plain)
                .padding(5)
                .frame(maxWidth: .infinity, alignment: .center)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(5)
            }
            
            Section("Einstellungen") {
                NavigationLink(value: NavigationPanel.settings) {
                    Label("Einstellungen", systemImage: NavigationPanel.settings.icon)
                }
            }
        }
        .listStyle(.sidebar)
        .frame(minWidth: 220)
    }
}