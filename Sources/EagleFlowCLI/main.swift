import Foundation
import ArgumentParser
import EagleFlow
import EagleFlowUtils
import Logging
import ServiceLifecycle

@main
struct EagleFlowCommand: ParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "eagleflow",
        abstract: "Ein Tool zum Verwalten und Bereitstellen von PDF-Dokumenten",
        subcommands: [Serve.self]
    )
}

extension EagleFlowCommand {
    struct Serve: ParsableCommand {
        static var configuration = CommandConfiguration(
            commandName: "serve",
            abstract: "Startet den EagleFlow-Server"
        )
        
        @Option(name: .shortAndLong, help: "Der Port, auf dem der Server laufen soll")
        var port: Int = 8080
        
        @Option(name: .shortAndLong, help: "Der Hostname, unter dem der Server erreichbar sein soll")
        var host: String = "localhost"
        
        @Option(name: .long, help: "Das Verzeichnis, das nach PDF-Dokumenten durchsucht werden soll")
        var documentDir: String?
        
        @Option(name: .long, help: "Der Pfad zum SSE-Endpunkt")
        var path: String = "/sse"
        
        @Flag(name: .shortAndLong, help: "Automatisch einen freien Port suchen, falls der angegebene belegt ist")
        var autoPort: Bool = false
        
        @Flag(name: .shortAndLong, help: "Server als Hintergrundprozess starten")
        var detach: Bool = false
        
        @Flag(name: .shortAndLong, help: "Ausführliche Protokollierung aktivieren")
        var verbose: Bool = false
        
        @Argument(help: "Zusätzliche PDF-Dateien, die bereitgestellt werden sollen")
        var pdfFiles: [String] = []
        
        func run() throws {
            // Bei detach = true als Hintergrundprozess starten
            if detach {
                try startAsBackground()
                return
            }
            
            // Hauptfunktion in einer Task starten
            Task {
                await startServer()
            }
            
            // Warte auf Beenden des Prozesses
            RunLoop.main.run()
        }
        
        func startAsBackground() throws {
            // Hier würde man den Prozess daemonisieren
            // Für macOS: launchd-Dienst erstellen oder ähnliches
            print(EagleFlowUtils.formatConsoleMessage("Hintergrundmodus ist noch nicht vollständig implementiert.", type: .warning))
            
            Task {
                await startServer()
            }
            
            RunLoop.main.run()
        }
        
        func startServer() async {
            let logger = Logger(label: "com.eagleflow.server", level: verbose ? .debug : .info)
            var serverPort = port
            
            // Auto-Port aktivieren, wenn gewünscht
            if autoPort {
                if let freePort = EagleFlowUtils.findFreePort(startingAt: port) {
                    serverPort = freePort
                    logger.info("Verwende automatisch gefundenen Port: \(serverPort)")
                } else {
                    logger.error("Konnte keinen freien Port finden")
                    print(EagleFlowUtils.formatConsoleMessage("Konnte keinen freien Port finden.", type: .error))
                    Foundation.exit(1)
                }
            }
            
            do {
                // Server erstellen
                let server = EagleFlowServer(name: "EagleFlowDocumentServer", version: "1.0.0", logger: logger)
                
                // Transport für Remote-Verbindungen erstellen
                let transport = HTTPServerTransport(host: host, port: serverPort, path: path, logger: logger)
                
                // Spezifische PDF-Dateien hinzufügen
                for pdfPath in pdfFiles {
                    do {
                        let expandedPath = EagleFlowUtils.expandPath(pdfPath)
                        if EagleFlowUtils.isPDFFile(at: expandedPath) {
                            try server.addPDFDocument(path: expandedPath)
                        } else {
                            logger.warning("Datei ist kein PDF oder existiert nicht: \(expandedPath)")
                        }
                    } catch {
                        logger.warning("Fehler beim Hinzufügen von \(pdfPath): \(error.localizedDescription)")
                    }
                }
                
                // Wenn ein Verzeichnis angegeben wurde, PDFs scannen
                if let dirPath = documentDir {
                    do {
                        let expandedPath = EagleFlowUtils.expandPath(dirPath)
                        logger.info("Scanne Verzeichnis nach PDF-Dokumenten: \(expandedPath)")
                        let count = try server.scanDirectoryForPDFs(directoryPath: expandedPath)
                        logger.info("Gefunden: \(count) PDF-Dokumente")
                        
                        print(EagleFlowUtils.formatConsoleMessage("\(count) PDF-Dokumente hinzugefügt aus \(expandedPath)", type: .success))
                    } catch {
                        logger.error("Fehler beim Scannen des Verzeichnisses: \(error.localizedDescription)")
                        print(EagleFlowUtils.formatConsoleMessage("Fehler beim Scannen des Verzeichnisses: \(error.localizedDescription)", type: .error))
                    }
                }
                
                // Prüfen, ob mindestens ein Dokument hinzugefügt wurde
                if server.getResources().isEmpty {
                    logger.warning("Keine PDF-Dokumente gefunden oder hinzugefügt")
                    print(EagleFlowUtils.formatConsoleMessage("Keine PDF-Dokumente gefunden oder hinzugefügt", type: .warning))
                }
                
                // Server starten
                print(EagleFlowUtils.formatConsoleMessage("Server wird gestartet auf http://\(host):\(serverPort) ...", type: .info))
                try await server.start(transport: transport)
                
                print(EagleFlowUtils.formatConsoleMessage("Server läuft und ist bereit für Verbindungen.", type: .success))
                print(EagleFlowUtils.formatConsoleMessage("MCP-Endpunkt: http://\(host):\(serverPort)\(path)", type: .info))
                print(EagleFlowUtils.formatConsoleMessage("Claude Desktop Konfiguration:", type: .info))
                print("""
                {
                  "mcpServers": {
                    "documentServer": {
                      "command": "npx",
                      "args": [
                        "mcp-remote",
                        "http://\(host):\(serverPort)\(path)"
                      ]
                    }
                  }
                }
                """)
                print(EagleFlowUtils.formatConsoleMessage("Drücke CTRL+C zum Beenden.", type: .info))
                
                // Signal-Handler einrichten
                SignalHandling.setupSignalHandlers {
                    print(EagleFlowUtils.formatConsoleMessage("\nServer wird beendet...", type: .info))
                    Task {
                        await server.stop()
                        print(EagleFlowUtils.formatConsoleMessage("Server wurde beendet.", type: .success))
                        Foundation.exit(0)
                    }
                }
                
                // Warten, bis der Task abgebrochen wird
                try await Task.sleep(for: .seconds(100 * 365 * 24 * 60 * 60)) // Praktisch für immer
                
            } catch {
                logger.error("Fehler beim Starten des Servers: \(error.localizedDescription)")
                print(EagleFlowUtils.formatConsoleMessage("Fehler beim Starten des Servers: \(error.localizedDescription)", type: .error))
                Foundation.exit(1)
            }
        }
    }
}

EagleFlowCommand.main()