import Foundation

// Represents different types of actions that can be performed
enum ActionType: String, Codable {
    case openFile
    case createFile
    case deleteFile
    case searchFiles
    case readFileContent
    case runApplication
    case systemCommand
    // Add more action types as needed
}

// Represents the parameters for different actions
struct ActionParameters: Codable {
    var filePath: String?
    var content: String?
    var searchQuery: String?
    var applicationName: String?
    var commandString: String?
    // Add more parameters as needed
}

// Represents a complete action with its type and parameters
struct Action: Codable {
    let type: ActionType
    let parameters: ActionParameters
}

struct AIResponse: Codable {
    struct Action: Codable {
        let type: String
        let parameters: [String: String]
    }
    let message: String
    let actions: [Action]?
}
