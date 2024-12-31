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

class VisionModelHandler {
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
        Analyze this screenshot and find the corresponding icon related to the user's prompt. For example the prompt "run the spotify app" or "open spotify" should result in moving to the location of the spotify icon as accurately as possible.

            
        1. Use the following considerations for a 13-inch MacBook Air display:
           - The screen resolution is approximately 1440px × 900px pixels (retina display, scaled).
           - The taskbar and application dock are typically at the bottom of the screen, so prioritize scanning the lower middle portion first for icons like Spotify.
           - Normalize coordinates between 0 and 1 relative to the full screen resolution.
           - Adjust `y` values considering that dock icons are often positioned closer to the bottom third of the screen. If you are running an application ALWAYS output a y coordinate of 0.05.
           - The middle of the screen should be 0.5 for the x coordinate, output x coordinates accordingly if they are to the right or left or the middle.

        2. For the best match found, provide:
           - Exact normalized coordinates (`x` and `y`) where to click.
           - Confidence score (`confidence`) between 0 and 1.
           - A brief description (`description`) of what was found and what you think of the user.

        Respond ONLY with a JSON object in this exact format:
        {
            "x": 0.XX,
            "y": 0.YY,
            "confidence": 0.ZZ,
            "description": "Brief description of what was found"
        }

        """

        let requestBody: [String: Any] = [
            "model": "gpt-4o-mini",
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
                                "url": "data:image/jpeg;base64,\(base64ImageData)"
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
        let nsImage = NSImage(cgImage: screenshot, size: NSSize(width: screenshot.width, height: screenshot.height))
        let response = try await sendImageToOpenAI(screenshot: nsImage, userPrompt: userPrompt)
        let location = try CursorControl.extractCoordinates(from: response)
        
        // Log the detection for debugging
        print("Found \(location.description) at (\(location.x), \(location.y)) with confidence \(location.confidence)")
        
        // Move and click if confidence is high enough
        moveAndClick(to: location)
        
        return location
    }
}
