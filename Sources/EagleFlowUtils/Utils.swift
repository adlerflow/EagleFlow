import Foundation
import Logging

/// Hilfsfunktionen für EagleFlow
public enum EagleFlowUtils {
    /// Expandiert Pfade mit Tilde
    /// - Parameter path: Der zu expandierende Pfad
    /// - Returns: Der expandierte Pfad
    public static func expandPath(_ path: String) -> String {
        return (path as NSString).expandingTildeInPath
    }
    
    /// Formatiert eine Meldung für die Konsole
    /// - Parameters:
    ///   - message: Die Meldung
    ///   - type: Der Meldungstyp (info, error, etc.)
    /// - Returns: Formatierte Meldung für die Konsole
    public static func formatConsoleMessage(_ message: String, type: ConsoleMessageType = .info) -> String {
        let icon: String
        
        switch type {
        case .info:
            icon = "ℹ️"
        case .success:
            icon = "✅"
        case .warning:
            icon = "⚠️"
        case .error:
            icon = "❌"
        }
        
        return "\(icon) \(message)"
    }
    
    /// Prüft, ob eine Datei existiert und ein PDF ist
    /// - Parameter path: Der zu prüfende Dateipfad
    /// - Returns: true wenn die Datei existiert und ein PDF ist
    public static func isPDFFile(at path: String) -> Bool {
        let fileManager = FileManager.default
        
        // Prüfe, ob die Datei existiert
        guard fileManager.fileExists(atPath: path) else {
            return false
        }
        
        // Einfache Prüfung anhand der Dateiendung
        return path.lowercased().hasSuffix(".pdf")
    }
    
    /// Ermittelt einen freien Port
    /// - Parameter startingAt: Der Port, ab dem gesucht werden soll
    /// - Returns: Ein freier Port oder nil, wenn keiner gefunden wurde
    public static func findFreePort(startingAt: Int = 8080) -> Int? {
        var port = startingAt
        
        // Probiere max. 100 Ports
        for _ in 0..<100 {
            // Prüfe, ob der Port frei ist
            var serverAddress = sockaddr_in()
            serverAddress.sin_family = sa_family_t(AF_INET)
            serverAddress.sin_port = in_port_t(port).bigEndian
            serverAddress.sin_addr.s_addr = inet_addr("0.0.0.0")
            
            let sock = socket(AF_INET, SOCK_STREAM, 0)
            if sock == -1 {
                continue
            }
            
            var reuse = 1
            if setsockopt(sock, SOL_SOCKET, SO_REUSEADDR, &reuse, socklen_t(MemoryLayout<Int>.size)) == -1 {
                close(sock)
                continue
            }
            
            let bindResult = withUnsafePointer(to: &serverAddress) {
                $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                    bind(sock, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
                }
            }
            
            if bindResult == 0 {
                close(sock)
                return port
            }
            
            close(sock)
            port += 1
        }
        
        return nil
    }
    
    /// Konsolen-Meldungstypen
    public enum ConsoleMessageType {
        case info
        case success
        case warning
        case error
    }
}