import Foundation

enum OpenAIError: Error {
    case rateLimitExceeded(resetTime: String)
    case invalidResponse
    case networkError(Error)
    case decodingError(Error)
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
        
        You are an AI assistant that helps users interact with their files, providing summaries, performing actions, running applications, and answering questions on macos.
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
                        "filePath": "/Downloads/file",  // Required for file actions, make it in Downloads directory unless its an application
                        "additionalData": data for the file action
                    }
                }
            ]
        }
        Here are some example action types you can use:
        - "openFile": To open a file specified by the user.
        - "createFile": To create a new file with the given content and file path.
        - "deleteFile": To delete a file at the specified path.
        - "renameFile": To rename a file at the specified path.
        - "moveFile": To move a file from one path to another.
        - "runApplication": Run an application, use applictaions folder
        - "updateFile": To update the content of an existing file.
        Make sure all file paths are in the downloads directory and that subdirectories are capatilized
        If a user asks for a file summary or something that doesn't require an action, simply return the answer in the "message" field, and do not include an "actions" field.
        
        You are a generalist and should assist users in a variety of ways. If the user asks to open any random file or to open a relevant file, select one from the list of files you have access to. If there are multiple relevant files, feel free to pick the most appropriate one.
        
        Remember the context of the conversation and track what the user has asked, as it may affect future interactions.
        When running applictaions or otherwise consider that this is a macbook air and use names accoridngly.
        IMPORTANT: if a user asks for a specific length make it that specific length.
        ABOVE ALL ELSE, respond in that JSON format

        """
        
        
        let requestBody: [String: Any] = [
            "model": "gpt-3.5-turbo-16k",
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": prompt],
            ],
            "max_tokens": 5000,  // Increase token limit for longer responses
            
            "temperature": 0.4
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
        
        return try handleResponse(httpResponse, data: data)

    }
    
    func handleResponse(_ response: HTTPURLResponse, data: Data) throws -> AIResponse {
        switch response.statusCode {
        case 200:
            // Attempt to decode the response as JSON
            do {
                let openAIResponse = try JSONDecoder().decode(OpenAIResponse.self, from: data)
                if let content = openAIResponse.choices.first?.message.content {
                    // Try to parse content as AIResponse
                    if let contentData = content.data(using: .utf8) {
                        do {
                            return try JSONDecoder().decode(AIResponse.self, from: contentData)
                        } catch {
                            // If JSON decoding fails, return plain text content
                            return AIResponse(message: content, actions: nil)
                        }
                    } else {
                        throw OpenAIError.invalidResponse
                    }
                } else {
                    throw OpenAIError.invalidResponse
                }
            } catch {
                // If the structure of OpenAIResponse fails, try handling it as a plain message
                if let rawContent = String(data: data, encoding: .utf8) {
                    return AIResponse(message: rawContent, actions: nil)
                } else {
                    throw OpenAIError.decodingError(error)
                }
            }

        case 429:
            throw OpenAIError.rateLimitExceeded(
                resetTime: response.value(forHTTPHeaderField: "X-RateLimit-Reset") ?? "unknown"
            )

        default:
            throw OpenAIError.invalidResponse
        }
    }

     
}
