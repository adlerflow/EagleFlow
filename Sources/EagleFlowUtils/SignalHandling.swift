import Foundation
import Dispatch

/// Hilfsfunktionen für die Signalbehandlung
public enum SignalHandling {
    /// Lock für Thread-sichere Zugriffe auf signalSources
    private static let lock = NSLock()
    
    /// Halten der Signal-Sources, um ihre Deallokation zu verhindern
    private static var _signalSources: [DispatchSourceSignal] = []
    
    /// Thread-sicherer Zugriff auf signalSources
    private static var signalSources: [DispatchSourceSignal] {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _signalSources
        }
        set {
            lock.lock()
            _signalSources = newValue
            lock.unlock()
        }
    }
    
    /// Richtet Signal-Handler für SIGINT und SIGTERM ein
    /// - Parameter handler: Der auszuführende Handler, wenn ein Signal empfangen wird
    /// - Returns: Leer; nutzt globale Variablen
    public static func setupSignalHandlers(handler: @escaping () -> Void) {
        // Signalverarbeitung in separater Queue
        let signalQueue = DispatchQueue(label: "com.eagleflow.signal-handler")
        
        // SIGINT (Ctrl+C) Handler
        let sigintSource = DispatchSource.makeSignalSource(signal: SIGINT, queue: signalQueue)
        sigintSource.setEventHandler {
            print("\nSIGINT empfangen, Server wird beendet...")
            handler()
        }
        signal(SIGINT, SIG_IGN) // Ignoriere Standard-Handler
        sigintSource.resume()
        
        // SIGTERM Handler
        let sigtermSource = DispatchSource.makeSignalSource(signal: SIGTERM, queue: signalQueue)
        sigtermSource.setEventHandler {
            print("\nSIGTERM empfangen, Server wird beendet...")
            handler()
        }
        signal(SIGTERM, SIG_IGN) // Ignoriere Standard-Handler
        sigtermSource.resume()
        
        // Speichere die Sources, damit sie nicht dealloziert werden
        signalSources = [sigintSource, sigtermSource]
    }
    
    /// Entferne Signal-Handler
    public static func removeSignalHandlers() {
        // Setze die Standard-Handler zurück
        signal(SIGINT, SIG_DFL)
        signal(SIGTERM, SIG_DFL)
        
        // Leere die Signal-Sources-Liste thread-sicher
        lock.lock()
        _signalSources.removeAll()
        lock.unlock()
    }
}