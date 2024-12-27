//
//  FileContextManager.swift
//  NothingOS
//
//  Created by Wafi Choudhury on 12/27/24.
//

import Foundation
import Combine

class FileContextManager: ObservableObject {
    @Published private(set) var fileContext: [String: String] = [:]
    
    // Add a method to update the file context
    func updateFile(with fileName: String, content: String) {
        fileContext[fileName] = content
    }
}

