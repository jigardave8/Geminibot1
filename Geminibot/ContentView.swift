import SwiftUI
import GoogleGenerativeAI

// Configuration for safe and controlled chat interactions
let config = GenerationConfig(
    temperature: 1.0,  // Controls randomness in responses
    topP: 0.95,       // Focuses responses on more likely continuations
    topK: 64,         // Considers a wider range of possible continuations
    maxOutputTokens: 8192, // Maximum length of generated responses
    responseMIMEType: "text/plain" // Plain text response format
)

// Secure way to store API key (replace with actual instructions)
// Secure way to store API key (replace with fatalError with actual logic)
func getApiKey() -> String {
    guard let apiKey = ProcessInfo.processInfo.environment["GEMINI_API_KEY"] else {
        fatalError("GEMINI_API_KEY environment variable not set!")
    }
    return apiKey
}




let apiKey = getApiKey() // Placeholder for secure retrieval

// Generative model with safety settings
let model = GenerativeModel(
    name: "gemini-1.5-pro-latest",
    apiKey: apiKey,
    generationConfig: config,
    safetySettings: [
        SafetySetting(harmCategory: .harassment, threshold: .blockMediumAndAbove),
        SafetySetting(harmCategory: .hateSpeech, threshold: .blockMediumAndAbove),
        SafetySetting(harmCategory: .sexuallyExplicit, threshold: .blockMediumAndAbove),
        SafetySetting(harmCategory: .dangerousContent, threshold: .blockMediumAndAbove)
    ]
)

// Chat initialization
var chat: Chat! // Global variable for maintaining conversation history

func startChat() {
    chat = model.startChat(history: []) // Initialize chat with empty history
}

// Send user input and receive response (function for reusability)
func sendUserMessage(_ message: String) async throws -> String {
    let response = try await chat.sendMessage(message)
    return response.text ?? "No response received"
}

struct ContentView: View {
    @State private var userInput = ""  // State variable for user input
    @State private var conversationHistory = [String]() // Array to store chat history

    var body: some View {
        VStack {
            // Display chat history
            ScrollView {
                ForEach(conversationHistory, id: \.self) { message in
                    Text(message)
                        .foregroundColor(.black) // Customize message color
                }
            }

            // Text field for user input
            TextField("Enter your message", text: $userInput)
                .onSubmit {
                    Task {
                        conversationHistory.append(userInput) // Add user input to history
                        let response = try? await sendUserMessage(userInput)
                        conversationHistory.append(response ?? "No response received")
                        userInput = "" // Clear input field for next message
                    }
                }
        }
        .padding()
        .onAppear { // Start chat on view appearance
            startChat()
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
