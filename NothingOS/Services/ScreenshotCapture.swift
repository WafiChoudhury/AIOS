//
//  ScreenshotCapture.swift
//  NothingOS
//
//  Created by Wafi Choudhury on 12/27/24.
//

import Foundation
import AppKit

class ScreenshotCapture {
    
    static func captureScreenshot() -> CGImage? {
        let screen = NSScreen.main!
        let rect = screen.frame
        let displayID = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as! CGDirectDisplayID
        
        return CGDisplayCreateImage(displayID)  // Capture the full screen
    }
    
    static func imageToBase64(image: CGImage) -> String {
        let imageRep = NSBitmapImageRep(cgImage: image)
        let imageData = imageRep.representation(using: .jpeg, properties: [:])
        return imageData?.base64EncodedString() ?? ""
    }
}
