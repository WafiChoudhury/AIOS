
import Foundation
import SwiftUI


class ChatViewModel: ObservableObject {
    @Published var messages: [Message] = []
    @Published var inputText: String = ""
    @Published var isLoading = false
    @Published var prompt: String = ""
    private let fileHandler: FileHandler
    private let openAIService: OpenAIService
    private let actionHandler: ActionHandler
    private var messageContext: [String]
    private let visionModelHandler: VisionModelHandler
    // Store file context (names and contents)
    private var fileContext: [String: String] = [:]
    private var filesLoaded = false // Flag to track if files have been loaded
    
    
    init() {
        let apiKey =  "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"
        self.fileHandler = FileHandler(apiKey: apiKey)
        self.visionModelHandler = VisionModelHandler()
        self.openAIService = OpenAIService(apiKey: apiKey)
        self.messageContext = []
        self.actionHandler = ActionHandler(fileHandler: fileHandler, visionModelHandler:visionModelHandler)

    }
    
    @MainActor
    func sendMessage() {
        guard !inputText.isEmpty else { return }
        
        let userMessage = Message(content: inputText, isUser: true)
        messages.append(userMessage)
        messageContext.append(inputText)

        let currentInput = inputText
        inputText = ""
        isLoading = true
        
        Task {
            await searchAndAnalyzeFiles(searchQuery: currentInput)
            isLoading = false
        }
    }
    @MainActor
    private func searchAndAnalyzeFiles(searchQuery: String) async {
        if !filesLoaded {
            let searchPath = "/Users/\(NSUserName())/Downloads"

            do {
                let fileManager = FileManager.default
                let url = URL(fileURLWithPath: searchPath)
                let foundFiles = try fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)
                
                if foundFiles.isEmpty {
                    await MainActor.run {
                        messages.append(Message(content: "No files found in the directory.", isUser: false))
                    }
                    return
                }
                
                // Parallelize file reading
                var fileContext: [String: String] = [:]
                await withTaskGroup(of: (String, String?).self) { group in
                    for fileURL in foundFiles {
                        group.addTask {
                            if let content = try? self.fileHandler.readFileContents(at: fileURL) {
                                return (fileURL.lastPathComponent, content)
                            }
                            return (fileURL.lastPathComponent, nil)
                        }
                    }
                    
                    for await (fileName, content) in group {
                        if let content = content {
                            fileContext[fileName] = content
                        }
                    }
                }
                
                self.fileContext = fileContext
                filesLoaded = true // Mark files as loaded
                
                let fileSummaries = fileContext
                    .filter { !$0.value.contains("DOCX") }
                    .map { file in
                        let words = file.value.split(separator: " ").prefix(20)
                        return "\(file.key): \(words.joined(separator: " "))..."
                    }
                    .joined(separator: "\n")
                
              prompt = """
                "\(searchQuery)"
                File contents (if relevant to query) and filepaths to open:
                \(fileSummaries)
                """
                try await processAIResponse(prompt: prompt)
                
            } catch {
                await MainActor.run {
                    messages.append(Message(content: "An error occurred while searching files: \(error.localizedDescription)", isUser: false))
                }
            }
        } else {
            // If files are already loaded, skip the file search

            prompt = """
            "\(searchQuery)"
            File contents (if relevant to query):
            \(fileContext.map { "\($0.key): \($0.value.prefix(50))..." }.joined(separator: "\n"))
            """
            try? await processAIResponse(prompt: prompt)
        }
    }
    
    @MainActor
    func addNewFileToContext(fileName: String, content: String) {
        // Update the fileContext with the new file
        fileContext[fileName] = content
        
        // Regenerate the file summaries
        let updatedFileSummaries = fileContext
            .map { file in
                let words = file.value.split(separator: " ").prefix(20)
                return "\(file.key): \(words.joined(separator: " "))..."
            }
            .joined(separator: "\n")
        
    }

    @MainActor
    func processAIResponse(prompt: String) async throws {
        do {
            let response = try await openAIService.getRelevantFiles(from: prompt)
            
            // Add AI's response message
            await MainActor.run {
                if let answer = extractAnswer(from: response) {
                    messages.append(Message(content: answer, isUser: false))
                }
            }
            print("ACTIONS", response)
            
            // Execute any actions returned by the AI
            if let actions = response.actions {
                for action in actions {
                    do {
                        try await actionHandler.executeAction(action, userPrompt: prompt)
                    } catch {
                        await MainActor.run {
                            messages.append(Message(content: "Error executing action: \(error.localizedDescription)", isUser: false))
                        }
                    }
                }
            }
        } catch {
            await MainActor.run {
                messages.append(Message(content: "An error occurred: \(error.localizedDescription)", isUser: false))
            }
        }

    }
    
    func extractAnswer(from aiResponse: AIResponse) -> String? {
        return aiResponse.message
    }
}
