import Foundation

enum OpenAIError: Error {
    case rateLimitExceeded(resetTime: String)
    case invalidResponse
    case networkError(Error)
    case decodingError(Error)
}


class OpenAIService {
    private let apiKey: String
    
    init(apiKey: String) {
        self.apiKey = apiKey
    }

    func getRelevantFiles(from prompt: String) async throws -> AIResponse {
        let url = URL(string: "https://api.openai.com/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let systemPrompt = """
        
        You are an AI assistant that helps users interact with their files, providing summaries, performing actions, and answering questions.
         When asked to create a file, please ensure it is at least one page long, you should make LARGE files when needed.
            If a user requests a file with specific content or length, ensure the content is both relevant and comprehensive, covering the topic in detail.
            If the content is too short, expand on it until it reaches the requested length.
        You must respond ONLY with valid JSON in this exact format, with no other text or explanation:

        {
            "message": "A message to show to the user",
            "actions": [
                {
                    "type": "<action_type>",  // e.g., openFile, createFile, deleteFile, etc.
                    "parameters": {
                        "filePath": "/path/to/file",  // Required for file actions, make it in Downloads directory
                        "additionalData": data for the file action
                    }
                }
            ]
        }
        ABOVE ALL ELSE, respond in that JSON format
        Here are some example action types you can use:
        - "openFile": To open a file specified by the user.
        - "createFile": To create a new file with the given content and file path.
        - "deleteFile": To delete a file at the specified path.
        - "renameFile": To rename a file at the specified path.
        - "moveFile": To move a file from one path to another.
        - "copyFile": To copy a file from one path to another.
        - "updateFile": To update the content of an existing file.
        Make sure all file paths are in the downloads directory and that subdirectories are capatilized
        If a user asks for a file summary or something that doesn't require an action, simply return the answer in the "message" field, and do not include an "actions" field.
        
        You are a generalist and should assist users in a variety of ways. If the user asks to open any random file or to open a relevant file, select one from the list of files you have access to. If there are multiple relevant files, feel free to pick the most appropriate one.
        
        Remember the context of the conversation and track what the user has asked, as it may affect future interactions.
        
        IMPORTANT: if a user asks for a specific length make it that specific length.
        """
        
        
        let requestBody: [String: Any] = [
            "model": "gpt-3.5-turbo-16k",
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": prompt]
            ],
            "max_tokens": 5000,  // Increase token limit for longer responses
            
            "temperature": 0.7
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        if let jsonString = String(data: data, encoding: .utf8) {
                    print("Raw OpenAI Response:")
                    print(jsonString)
                }
        guard let httpResponse = response as? HTTPURLResponse else {
            throw OpenAIError.invalidResponse
        }
        
        switch httpResponse.statusCode {
        case 200:
            let openAIResponse = try JSONDecoder().decode(OpenAIResponse.self, from: data)
            guard let contentString = openAIResponse.choices.first?.message.content,
                  let contentData = contentString.data(using: .utf8) else {
                throw OpenAIError.invalidResponse
            }
            
            return try JSONDecoder().decode(AIResponse.self, from: contentData)
            
        case 429:
            if let resetTime = httpResponse.value(forHTTPHeaderField: "X-RateLimit-Reset") {
                throw OpenAIError.rateLimitExceeded(resetTime: resetTime)
            }
            throw OpenAIError.invalidResponse
            
        default:
            throw OpenAIError.invalidResponse
        }
    }
     
    private struct OpenAIResponse: Codable {
        struct Choice: Codable {
            struct Message: Codable {
                let content: String
            }
            let message: Message
        }
        let choices: [Choice]
    }
}
