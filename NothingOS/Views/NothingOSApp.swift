//
//  NothingOSApp.swift
//  NothingOS
//
//  Created by Wafi Choudhury on 12/17/24.
//

import SwiftUI

@main
struct NothingOSApp: App {
    
    
   
    func printAllFonts() {
        let fontManager = NSFontManager.shared
        let fontFamilies = fontManager.availableFontFamilies
        
        for family in fontFamilies {
            print("Font Family: \(family)")
            if let fonts = fontManager.availableMembers(ofFontFamily: family) {
                for font in fonts {
                    if let fontName = font.first as? String {
                        print("  Font Name: \(fontName)")
                    }
                }
            }
        }
    }

        
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
