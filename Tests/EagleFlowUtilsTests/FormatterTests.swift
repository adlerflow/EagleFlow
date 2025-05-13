import XCTest
import MCP
@testable import EagleFlowUtils
@testable import EagleFlow

final class FormatterTests: XCTestCase {
    func testFormatTextContent() {
        let content: [Tool.Content] = [
            .text("Hello, world!")
        ]
        
        let formatted = ContentFormatter.formatContent(content)
        XCTAssertEqual(formatted, "Hello, world!\n")
    }
    
    func testFormatImageContent() {
        let content: [Tool.Content] = [
            .image(Data(), "image/png", ["width": 800, "height": 600])
        ]
        
        let formatted = ContentFormatter.formatContent(content)
        XCTAssertEqual(formatted, "[Image: 800x600 image/png]\n")
    }
    
    func testFormatAudioContent() {
        let content: [Tool.Content] = [
            .audio(Data(), "audio/mp3")
        ]
        
        let formatted = ContentFormatter.formatContent(content)
        XCTAssertEqual(formatted, "[Audio: audio/mp3]\n")
    }
    
    func testFormatResourceContent() {
        let content: [Tool.Content] = [
            .resource("resource://example", "text/plain", "Example resource")
        ]
        
        let formatted = ContentFormatter.formatContent(content)
        XCTAssertEqual(formatted, "[Resource: resource://example (text/plain)]\n")
    }
    
    func testFormatMixedContent() {
        let content: [Tool.Content] = [
            .text("Text content"),
            .image(Data(), "image/jpeg", ["width": 1024, "height": 768]),
            .audio(Data(), "audio/wav")
        ]
        
        let formatted = ContentFormatter.formatContent(content)
        XCTAssertEqual(formatted, "Text content\n[Image: 1024x768 image/jpeg]\n[Audio: audio/wav]\n")
    }
    
    func testFormatPrompts() {
        let prompts: [Prompt] = [
            Prompt(
                name: "greeting",
                description: "A friendly greeting",
                arguments: [
                    Prompt.Argument(name: "name", description: "Person's name", required: true),
                    Prompt.Argument(name: "formal", description: "Whether to use formal language")
                ]
            )
        ]
        
        let formatted = ContentFormatter.formatPrompts(prompts)
        XCTAssertTrue(formatted.contains("- greeting: A friendly greeting"))
        XCTAssertTrue(formatted.contains("- name (required): Person's name"))
        XCTAssertTrue(formatted.contains("- formal: Whether to use formal language"))
    }
    
    func testFormatTools() {
        let tools: [Tool] = [
            Tool(name: "calculator", description: "Perform calculations"),
            Tool(name: "translator", description: "Translate text")
        ]
        
        let formatted = ContentFormatter.formatTools(tools)
        XCTAssertTrue(formatted.contains("- calculator: Perform calculations"))
        XCTAssertTrue(formatted.contains("- translator: Translate text"))
    }
}