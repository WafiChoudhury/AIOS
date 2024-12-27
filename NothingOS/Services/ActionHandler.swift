import Foundation
import AppKit
class ActionHandler {
    private let fileHandler: FileHandler

    init(fileHandler: FileHandler) {
          self.fileHandler = fileHandler
      }
    func executeAction(_ action: AIResponse.Action) async throws {
        switch action.type {
        case "openFile":
            guard var filePath = action.parameters["filePath"] else {
                throw ActionError.missingParameter("filePath for openFile action")
            }
            filePath = "/Users/\(NSUserName())" + filePath
            print("FILEPATH", filePath)
            try openFile(at: filePath)
            
        case "createFile":
            guard let filePath = action.parameters["filePath"],
                  let content = action.parameters["additionalData"] else {
                throw ActionError.missingParameter("filePath or content for createFile action")
            }
            try createFile(at: "/Users/\(NSUserName())/"+filePath, content: content)
            
            
        case "searchFiles":
            guard let query = action.parameters["searchQuery"] else {
                throw ActionError.missingParameter("searchQuery for searchFiles action")
            }
            let directory = URL(fileURLWithPath: "/Users/\(NSUserName())/Downloads")
            _ = try fileHandler.searchFiles(withNameContaining: query, in: directory)
            
        case "runApplication":
            guard let appName = action.parameters["applicationName"] else {
                throw ActionError.missingParameter("applicationName for runApplication action")
            }
            try runApplication(named: appName)
            
        case "systemCommand":
            guard let command = action.parameters["commandString"] else {
                throw ActionError.missingParameter("commandString for systemCommand action")
            }
            try executeSystemCommand(command)
            
        default:
            throw ActionError.unsupportedAction(action.type)
        }
    }
    
    private func openFile(at path: String) throws {
        let url = URL(fileURLWithPath: path)
        print("HERE")
        NSWorkspace.shared.open(url)
    }
    
    private func createFile(at path: String, content: String) throws {
        try content.write(to: URL(fileURLWithPath: path), atomically: true, encoding: .utf8)
    }
    
    private func runApplication(named appName: String) throws {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: appName) else {
            throw ActionError.applicationNotFound(appName)
        }
        try NSWorkspace.shared.launchApplication(at: url,
                                               options: .default,
                                               configuration: [:])
    }
    
    private func executeSystemCommand(_ command: String) throws {
        let process = Process()
        process.launchPath = "/bin/bash"
        process.arguments = ["-c", command]
        try process.run()
    }
}

enum ActionError: Error {
    case missingParameter(String)
    case unsupportedAction(String)
    case applicationNotFound(String)
    case systemError(String)
}
