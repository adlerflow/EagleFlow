import SwiftUI

struct DocumentsView: View {
    @ObservedObject var viewModel: ServerViewModel
    @State private var selectedDocument: PDFDocument?
    
    // Grid-Layout analog zu Food Truck
    let columns = [
        GridItem(.adaptive(minimum: 160, maximum: 200), spacing: 20)
    ]
    
    var body: some View {
        VStack {
            if viewModel.documents.isEmpty {
                VStack(spacing: 20) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 64))
                        .foregroundColor(.secondary)
                    
                    Text("Keine PDF-Dokumente")
                        .font(.title2)
                    
                    Text("Füge PDFs hinzu, um sie über MCP bereitzustellen.")
                        .foregroundColor(.secondary)
                    
                    Button("PDF hinzufügen...") {
                        viewModel.addPDFDocument()
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.top)
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 20) {
                        ForEach(viewModel.documents) { document in
                            DocumentCard(document: document, isSelected: selectedDocument?.id == document.id)
                                .aspectRatio(0.7, contentMode: .fit)
                                .onTapGesture {
                                    selectedDocument = document
                                }
                                .contextMenu {
                                    Button("Entfernen") {
                                        viewModel.removeDocument(document)
                                        if selectedDocument?.id == document.id {
                                            selectedDocument = nil
                                        }
                                    }
                                }
                        }
                    }
                    .padding()
                }
            }
        }
        .navigationTitle("PDF-Dokumente")
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button {
                    viewModel.addPDFDocument()
                } label: {
                    Label("PDF hinzufügen", systemImage: "plus")
                }
            }
            
            ToolbarItem(placement: .automatic) {
                Button {
                    viewModel.scanDirectory()
                } label: {
                    Label("Verzeichnis scannen", systemImage: "folder.badge.plus")
                }
            }
        }
        .sheet(item: $selectedDocument) { document in
            DocumentDetailView(document: document, viewModel: viewModel)
        }
    }
}

// Dokumentenkarte im Food Truck Design-Stil
struct DocumentCard: View {
    let document: PDFDocument
    let isSelected: Bool
    
    var body: some View {
        VStack {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.white)
                    .shadow(radius: 2)
                
                VStack {
                    Image(systemName: "doc.text.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 60, height: 60)
                        .foregroundColor(.blue)
                        .padding(.top, 20)
                    
                    Text(document.name)
                        .font(.headline)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 8)
                        .padding(.bottom, 8)
                    
                    Spacer()
                }
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 3)
        )
    }
}

// Detail-Ansicht im Food Truck Stil
struct DocumentDetailView: View {
    let document: PDFDocument
    @ObservedObject var viewModel: ServerViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack {
            HStack {
                Text(document.name)
                    .font(.largeTitle)
                    .bold()
                
                Spacer()
                
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            
            Divider()
            
            VStack(alignment: .leading, spacing: 12) {
                InfoRow(title: "Name:", value: document.name)
                InfoRow(title: "Pfad:", value: document.path)
                if !document.uri.isEmpty {
                    InfoRow(title: "MCP URI:", value: document.uri)
                }
            }
            .padding()
            
            Spacer()
            
            if !viewModel.isServerRunning {
                Button("Server starten und Dokument bereitstellen") {
                    viewModel.startServer()
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .padding()
            }
        }
        .frame(width: 500, height: 300)
    }
}

struct InfoRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack(alignment: .top) {
            Text(title)
                .frame(width: 80, alignment: .trailing)
                .foregroundColor(.secondary)
            
            Text(value)
                .textSelection(.enabled)
        }
    }
}