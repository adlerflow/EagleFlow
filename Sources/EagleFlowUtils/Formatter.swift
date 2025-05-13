import Foundation
import EagleFlow
import MCP

/// Utility class for formatting MCP content
public struct ContentFormatter {
    /// Format tool content as readable text
    /// - Parameter content: Array of Tool.Content items
    /// - Returns: Formatted string representation
    public static func formatContent(_ content: [Tool.Content]) -> String {
        var result = ""
        
        for item in content {
            switch item {
            case .text(let text):
                result += text + "\n"
                
            case .image(_, let mimeType, let metadata):
                var description = "[Image: \(mimeType)]"
                if let width = metadata?["width"] as? Int,
                   let height = metadata?["height"] as? Int {
                    description = "[Image: \(width)x\(height) \(mimeType)]"
                }
                result += description + "\n"
                
            case .audio(_, let mimeType):
                result += "[Audio: \(mimeType)]\n"
                
            case .resource(let uri, let mimeType, _):
                result += "[Resource: \(uri) (\(mimeType))]\n"
            }
        }
        
        return result
    }
    
    /// Format a list of prompts in a human-readable format
    /// - Parameter prompts: Array of Prompt objects
    /// - Returns: Formatted string representation
    public static func formatPrompts(_ prompts: [Prompt]) -> String {
        var result = "Available Prompts:\n"

        for prompt in prompts {
            result += "- \(prompt.name): \(prompt.description ?? "No description")\n"

            if let arguments = prompt.arguments, !arguments.isEmpty {
                result += "  Arguments:\n"
                for arg in arguments {
                    let required = arg.required ?? false ? " (required)" : ""
                    result += "  - \(arg.name)\(required): \(arg.description ?? "No description")\n"
                }
            }
            result += "\n"
        }

        return result
    }
    
    /// Format a list of tools in a human-readable format
    /// - Parameter tools: Array of Tool objects
    /// - Returns: Formatted string representation
    public static func formatTools(_ tools: [Tool]) -> String {
        var result = "Available Tools:\n"

        for tool in tools {
            result += "- \(tool.name): \(tool.description)\n"
        }

        return result
    }
}