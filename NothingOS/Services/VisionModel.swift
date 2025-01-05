import Foundation
import CoreGraphics
import ScreenCaptureKit
import SwiftUI
import AppKit
import Cocoa

struct IconLocation: Codable {
    let x: Float
    let y: Float
    let confidence: Float
    let description: String
    
    enum CodingKeys: String, CodingKey {
        case x, y, confidence, description
    }
}

// Decode the initial response to extract the text
struct OuterResponse: Decodable {
    struct Candidate: Decodable {
        struct Content: Decodable {
            let parts: [Part]
        }

        struct Part: Decodable {
            let text: String
        }

        let content: Content
    }

    let candidates: [Candidate]
}
// Define a response structure for the Gemini model (or any vision AI model).
struct GeminiVisionResponse: Decodable {
    let box: [Int] // [ymin, xmin, ymax, xmax]
    let confidence: Double
}


class VisionModelHandler {
    

    func sendImageToGeminiModel(screenshot: NSImage, userPrompt: String) async throws -> GeminiVisionResponse {
    

        // Convert the NSImage to Base64 format
        guard let base64ImageData = convertImageToBase64(image: screenshot) else {
            throw NSError(domain: "ImageConversion", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to convert image to base64"])
        }

        // Define the prompt for Gemini
        let promptText = """
        UserPrompt:\(userPrompt)
        
        You are a model that finds UI elemnts. Analyze this screenshot and find the bounding box for the icon related to the user's prompt. For example the prompt "run the spotify app" or "open spotify" should result in moving to the location of the spotify icon as accurately as possible. You are trying to bound whatever subject in the user's prompt. Ex) pause currrent song, in your response, reutrn the bounding box for the pause button. Ex) for prompts like "Imesssage" just return the box for imessage or that UI element. Tightly bound icons as much as possible, keep the boxes small and accurate, precision is the key.
            Respond ONLY with a JSON object in this exact format:
            {
                "box": [ymin, xmin, ymax, xmax]
                "confidence": 0.ZZ,
            }
        ALWAYS return in that format. Be ACCURATE, the box should surround only the target element.
        """
        
        print("PROMPT", promptText)
        
        // Create the HTTP request
        var request = URLRequest(url: URL(string: "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=AIzaSyBD-WbVQlV6Ccp-YD4MzDpjARRQ2U7kC2w")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Simplified request body matching the curl format
        let requestBody: [String: Any] = [
            "contents": [
                [
                    "parts": [
                        ["inlineData": [
                            "mimeType": "image/png",
                            "data": base64ImageData
                        ]],
                        ["text": promptText]
                    ]
                ]
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        let (data, response) = try await URLSession.shared.data(for: request)
        print(response)
        // Validate response
        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
            print("Error: \(httpResponse.statusCode)")
        }
        if let jsonString = String(data: data, encoding: .utf8) {
               print("Raw JSON:", jsonString)
           }
        
        let outerResponse = try JSONDecoder().decode(OuterResponse.self, from: data)
        guard let text = outerResponse.candidates.first?.content.parts.first?.text else {
            throw NSError(domain: "ParsingError", code: 1, userInfo: [NSLocalizedDescriptionKey: "No text found in response"])
        }

        // Clean the text to remove markdown code block indicators
        let cleanedText = text
            .replacingOccurrences(of: "```json\n", with: "")
            .replacingOccurrences(of: "\n```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        print("Cleaned Text: \(cleanedText)")

        // Decode the cleaned JSON text into GeminiVisionResponse
        let embeddedData = Data(cleanedText.utf8)
        let geminiResponse = try JSONDecoder().decode(GeminiVisionResponse.self, from: embeddedData)

        print("Parsed Gemini Response: \(geminiResponse)")
        
        return geminiResponse
    }



    func convertImageToBase64(image: NSImage) -> String? {
        guard let imageData = image.tiffRepresentation else {
            return nil
        }
        guard let bitmapImageRep = NSBitmapImageRep(data: imageData),
              let pngData = bitmapImageRep.representation(using: .png, properties: [:]) else {
            return nil
        }
        return pngData.base64EncodedString()
    }

    func sendImageToOpenAI(screenshot: NSImage, userPrompt:String) async throws -> AIVisionResponse {
        let url = URL(string: "https://api.openai.com/v1/chat/completions")!

        guard let base64ImageData = convertImageToBase64(image: screenshot) else {
            throw NSError(domain: "ImageConversion", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to convert image to base64"])
        }
      
        let promptText = """
        \(userPrompt)
        Analyze this screenshot with a grid and find the corresponding icon related to the user's prompt. For example the prompt "run the spotify app" or "open spotify" should result in moving to the location of the spotify icon as accurately as possible.

            
        1. Use the following considerations for a 13-inch MacBook Air display:
           - The screen resolution is approximately 1440px × 900px pixels (retina display, scaled).
           - The taskbar and application dock are typically at the bottom of the screen, so prioritize scanning the lower middle portion first for icons like Spotify.
           - Normalize coordinates between 0 and 1 relative to the full screen resolution.
           - Adjust `y` values considering that dock icons are often positioned closer to the bottom third of the screen. If you are running an application ALWAYS output a y coordinate of 0.05.
           - Output values related to what bounding box the object is in and the relative normalized x and y values.

        2. For the best match found, provide:
           - Exact normalized coordinates (`x` and `y`) where to click.
           - Confidence score (`confidence`) between 0 and 1.
           - A brief description (`description`) of what was found and what position in the grid.

        Respond ONLY with a JSON object in this exact format:
        {
            "x": 0.XX,
            "y": 0.YY,
            "confidence": 0.ZZ,
            "description": "Brief description of what was found and at which grid location, ex A5
        }
        Find the corresponding grid first then find the x,y coordinates based on that. E8 maps to x:0.314, y:0.05 for example
        """

        let requestBody: [String: Any] = [
            "model": "gpt-4o-2024-08-06",
            "messages": [
                [
                    "role": "user",
                    "content": [
                        [
                            "type": "text",
                            "text": promptText
                        ],
                        [
                            "type": "image_url",
                            "image_url": [
                                "url": "data:image/png;base64,\(base64ImageData)"
                            ]
                        ]
                    ]
                ]
            ],
            "max_tokens": 300,
            "temperature": 0.2 // Lower temperature for more precise responses
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer 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", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        let (data, response) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
            print("Error: \(httpResponse.statusCode)")
            let responseString = String(data: data, encoding: .utf8) ?? "No response"
            print("Response: \(responseString)")
            throw NSError(domain: "APIError", code: httpResponse.statusCode,
                        userInfo: [NSLocalizedDescriptionKey: "Request failed with status code \(httpResponse.statusCode)"])
        }
        let responseString = String(data: data, encoding: .utf8)
        print(responseString)
        return try JSONDecoder().decode(AIVisionResponse.self, from: data)
    }


    func overlayGrid(on image: NSImage, rows: Int, columns: Int, padding: CGFloat) -> NSImage? {
        let originalSize = image.size
        let paddedSize = NSSize(width: originalSize.width + 2 * padding, height: originalSize.height + 2 * padding)
        let cellWidth = originalSize.width / CGFloat(columns)
        let cellHeight = originalSize.height / CGFloat(rows)
        
        // Create a new image with the padded size
        let newImage = NSImage(size: paddedSize)
        newImage.lockFocus()
        
        // Fill the background with white
        NSColor.white.setFill()
        NSBezierPath(rect: NSRect(origin: .zero, size: paddedSize)).fill()
        
        // Draw the original image, centered with padding
        let drawRect = NSRect(x: padding, y: padding, width: originalSize.width, height: originalSize.height)
        image.draw(in: drawRect)
        
        // Set grid line color and thickness
        let gridColor = NSColor.black
        gridColor.set()
        let gridThickness: CGFloat = 4.0
        
        // Draw vertical lines
        for column in 0...columns {
            let x = padding + CGFloat(column) * cellWidth
            let path = NSBezierPath()
            path.lineWidth = gridThickness
            path.move(to: NSPoint(x: x, y: padding))
            path.line(to: NSPoint(x: x, y: paddedSize.height - padding))
            path.stroke()
        }
        
        // Draw horizontal lines
        for row in 0...rows {
            let y = padding + CGFloat(row) * cellHeight
            let path = NSBezierPath()
            path.lineWidth = gridThickness
            path.move(to: NSPoint(x: padding, y: y))
            path.line(to: NSPoint(x: paddedSize.width - padding, y: y))
            path.stroke()
        }
        
        // Add column letters (A, B, C, ...) at the top and bottom
        for column in 0..<columns {
            let x = padding + CGFloat(column) * cellWidth + cellWidth / 2
            let letter = String(UnicodeScalar("A".unicodeScalars.first!.value + UInt32(column))!)
            drawText(letter, at: NSPoint(x: x - 5, y: paddedSize.height - padding + 20)) // Top
            drawText(letter, at: NSPoint(x: x - 5, y: padding - 55)) // Bottom
        }
        
        // Add row numbers (1, 2, 3, ...) at the left and right
        for row in 0..<rows {
            let y = padding + CGFloat(row) * cellHeight + cellHeight / 2
            let number = "\(row + 1)"
            drawText(number, at: NSPoint(x: padding - 40, y: paddedSize.height - y - 8)) // Left
            drawText(number, at: NSPoint(x: paddedSize.width - padding + 5, y: paddedSize.height - y - 8)) // Right
        }
        
        newImage.unlockFocus()
        return newImage
    }

    // Helper function to draw text
    func drawText(_ text: String, at point: NSPoint) {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.boldSystemFont(ofSize: 45),
            .foregroundColor: NSColor.black
        ]
        let attributedString = NSAttributedString(string: text, attributes: attributes)
        attributedString.draw(at: point)
    }
    func moveAndClick(to location: IconLocation) {
        // Move cursor

        CursorControl.moveCursorTo(x: location.x, y: location.y)
        Thread.sleep(forTimeInterval: 0.1)
        
        // Perform click if confidence is high enough
        if location.confidence > 0.8 {
            print("CONFIDENT")
        }
    }

    func processVisionResponse(for screenshot: CGImage, userPrompt:String) async throws -> IconLocation {
        // Create an NSImage from the provided CGImage
           let nsImage = NSImage(cgImage: screenshot, size: NSSize(width: screenshot.width, height: screenshot.height))
           
//           // Generate a grid image with padding
//           let rows = 8
//           let columns = 15
//           let padding: CGFloat = 100
//           guard let gridImage = overlayGrid(on: nsImage, rows: rows, columns: columns, padding: padding) else {
//               throw NSError(domain: "GridImageGenerationError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to generate grid image"])
//           }
//           

           // Send the grid image to OpenAI for processing
           let response = try await sendImageToGeminiModel(screenshot: nsImage, userPrompt: userPrompt)
           let location = try CursorControl.extractCoordinates(from: response, imageWidth: 1400, imageHeight: 899)
            
        // Log the detection for debugging
        print("Found \(location.description) at (\(location.x), \(location.y)) with confidence \(location.confidence)")
        
        // Move and click if confidence is high enough
        moveAndClick(to: location)
        
        return location
    }
}
