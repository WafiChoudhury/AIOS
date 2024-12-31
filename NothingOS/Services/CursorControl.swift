//
//  CursorControl.swift
//  NothingOS
//
//  Created by Wafi Choudhury on 12/27/24.
//

import Foundation
import AppKit

class CursorControl {
    
    static func moveCursorTo(x: Float, y: Float) {
            guard let screen = NSScreen.main else {
                print("Failed to get main screen")
                return
            }
            
            let screenFrame = screen.frame
            let screenHeight = screenFrame.height
            let screenWidth = screenFrame.width
        let position = CGPoint(x: CGFloat(x) * screenWidth, y: screenHeight - CGFloat(y) * screenHeight ) // Invert Y for macOS screen coordinates
            print("Moving cursor to: \(position)")
            
            // Create a Quartz mouse move event
            let event = CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: position, mouseButton: .left)
            
            // Post the event
            event?.post(tap: .cghidEventTap)
        }
    static func extractCoordinates(from response: AIVisionResponse) throws -> IconLocation {
            guard let content = response.choices.first?.message.content else {
                throw NSError(domain: "ParsingError", code: 1,
                             userInfo: [NSLocalizedDescriptionKey: "No content in response"])
            }
            
            // Remove markdown code block indicators if present
            let cleanContent = content
                .replacingOccurrences(of: "```json\n", with: "")
                .replacingOccurrences(of: "\n```", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            
            print("Cleaned content for parsing: \(cleanContent)") // Debug print
            
            guard let jsonData = cleanContent.data(using: .utf8),
                  let location = try? JSONDecoder().decode(IconLocation.self, from: jsonData) else {
                throw NSError(domain: "ParsingError", code: 2,
                             userInfo: [NSLocalizedDescriptionKey: "Failed to parse coordinates from content: \(cleanContent)"])
            }
            
            return location
        }
}
