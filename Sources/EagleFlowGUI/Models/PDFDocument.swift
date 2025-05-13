import Foundation

/// Datenmodell für ein PDF-Dokument in der GUI-App
struct PDFDocument: Identifiable {
    /// Eindeutige ID des Dokuments
    let id: String
    
    /// Anzeigename des Dokuments
    var name: String
    
    /// MCP-URI des Dokuments (leer, wenn noch nicht im Server registriert)
    var uri: String
    
    /// Lokaler Dateipfad zum PDF
    var path: String
}