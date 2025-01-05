//
//  CursorControl.swift
//  NothingOS
//
//  Created by Wafi Choudhury on 12/27/24.
//

import Foundation
import AppKit

struct BoundingBox {
    let ymin: CGFloat
    let xmin: CGFloat
    let ymax: CGFloat
    let xmax: CGFloat
}

class CursorControl {
    
    static func moveCursorTo(x: Float, y: Float) {
            guard let screen = NSScreen.main else {
                print("Failed to get main screen")
                return
            }
            
//            let screenFrame = screen.frame
//            let screenHeight = screenFrame.height
//            let screenWidth = screenFrame.width
        let position = CGPoint(x: CGFloat(x), y: CGFloat(y) ) // Invert Y for macOS screen coordinates
            print("Moving cursor to: \(position)")
            
            // Create a Quartz mouse move event
            let event = CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: position, mouseButton: .left)
            
            // Post the event
            event?.post(tap: .cghidEventTap)
        
        
            //click on the coordinates
            let mouseDown = CGEvent(mouseEventSource: nil, mouseType: .leftMouseDown, mouseCursorPosition: position, mouseButton: .left)
            let mouseUp = CGEvent(mouseEventSource: nil, mouseType: .leftMouseUp, mouseCursorPosition: position, mouseButton: .left)
           
           // Post the first click
           mouseDown?.post(tap: .cghidEventTap)
           mouseUp?.post(tap: .cghidEventTap)
           
           // Add a short delay to mimic human double-click timing
           usleep(150_000) // 150 milliseconds
           
           // Post the second click
           mouseDown?.post(tap: .cghidEventTap)
           mouseUp?.post(tap: .cghidEventTap)
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
    static func extractCoordinates(
        from response: GeminiVisionResponse,
        imageWidth: CGFloat,
        imageHeight: CGFloat
    ) throws -> IconLocation {
        // Ensure the bounding box is available in the response
        guard response.box.count == 4 else {
            throw NSError(domain: "ParsingError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Bounding box not found in response"])
        }

        // Extract and normalize the bounding box coordinates
        let normalizedBox = BoundingBox(
            ymin: CGFloat(response.box[0]) / 1000.0,
            xmin: CGFloat(response.box[1]) / 1000.0,
            ymax: CGFloat(response.box[2]) / 1000.0,
            xmax: CGFloat(response.box[3]) / 1000.0
        )

        // Convert normalized coordinates to pixel coordinates
        let pixelYMin = normalizedBox.ymin * imageHeight
        let pixelXMin = normalizedBox.xmin * imageWidth
        let pixelYMax = normalizedBox.ymax * imageHeight
        let pixelXMax = normalizedBox.xmax * imageWidth

        // Calculate the center of the bounding box
        let centerX = (pixelXMin + pixelXMax) / 2
        let centerY = (pixelYMin + pixelYMax) / 2 
        
        print(centerX, centerY)
        // Create and return the IconLocation
        return IconLocation(
            x: Float(centerX),
            y: Float(centerY),
            confidence: Float(response.confidence),
            description: "Bounding box center extracted from Gemini response"
        )
    }

}
