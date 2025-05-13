import SwiftUI

/// Seitenleiste mit PDF-Liste
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