# EagleFlow

Ein MCP-Server zur Bereitstellung von PDF-Dokumenten für Claude und andere MCP-fähige KI-Assistenten.

## Funktionen

- Bereitstellung lokaler PDF-Dokumente über das Model Context Protocol (MCP)
- Kompatibel mit Claude Desktop und anderen MCP-Clients
- Einfache Bedienung über GUI oder Kommandozeile
- Unterstützt macOS, iOS, tvOS, watchOS und visionOS

## Installation

### Als Entwickler

1. Repository klonen:
   ```bash
   git clone https://github.com/yourusername/EagleFlow.git
   cd EagleFlow
   ```

2. Abhängigkeiten installieren und kompilieren:
   ```bash
   swift build
   ```

3. Ausführen:
   ```bash
   swift run EagleFlowCLI serve --document-dir ~/Documents
   ```

## CLI-Verwendung

### Server starten

```bash
# Grundlegende Verwendung
swift run EagleFlowCLI serve

# Mit Verzeichnis-Scan
swift run EagleFlowCLI serve --document-dir ~/Documents

# Mit spezifischen PDF-Dateien
swift run EagleFlowCLI serve document1.pdf document2.pdf

# Mit angepasstem Port und Host
swift run EagleFlowCLI serve -p 3000 -h 0.0.0.0 --document-dir ~/Documents

# Mit automatischer Portsuche, falls Port belegt ist
swift run EagleFlowCLI serve -a --document-dir ~/Documents

# Mit ausführlicher Protokollierung
swift run EagleFlowCLI serve -v --document-dir ~/Documents
```

### Parameter

- `-p, --port <port>`: Port, auf dem der Server laufen soll (Standard: 8080)
- `-h, --host <host>`: Hostname, unter dem der Server erreichbar sein soll (Standard: localhost)
- `--document-dir <path>`: Verzeichnis, das nach PDF-Dokumenten gescannt werden soll
- `--path <path>`: Pfad zum SSE-Endpunkt (Standard: /sse)
- `-a, --auto-port`: Automatisch einen freien Port suchen, falls der angegebene belegt ist
- `-d, --detach`: Server als Hintergrundprozess starten
- `-v, --verbose`: Ausführliche Protokollierung aktivieren

## GUI-Anwendung

EagleFlow bietet auch eine grafische Benutzeroberfläche (GUI), die den Umgang mit PDF-Dokumenten erleichtert:

```bash
swift run EagleFlowGUI
```

Mit der GUI können Sie:
- PDF-Dokumente per Drag & Drop hinzufügen
- Verzeichnisse nach PDFs scannen
- Den Server mit einem Klick starten und stoppen
- Die Claude Desktop Konfiguration kopieren

## Claude Desktop Integration

Um EagleFlow mit Claude Desktop zu verwenden, fügen Sie folgende Konfiguration in die Claude Desktop Einstellungen ein:

```json
{
  "mcpServers": {
    "documentServer": {
      "command": "npx",
      "args": [
        "mcp-remote",
        "http://localhost:8080/sse"
      ]
    }
  }
}
```

## Entwicklung

EagleFlow verwendet die folgenden Hauptkomponenten:

- **EagleFlowServer**: Der MCP-Server, der PDF-Dokumente als Ressourcen bereitstellt
- **HTTPServerTransport**: Der HTTP-Server mit SSE-Unterstützung für MCP-Kommunikation
- **EagleFlowCLI**: Die Kommandozeilen-Schnittstelle
- **EagleFlowGUI**: Die grafische Benutzeroberfläche

## Lizenz

MIT Lizenz