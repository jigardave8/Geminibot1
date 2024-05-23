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

// Secure way to store API key (replace with actual logic)
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

struct Message: Identifiable, Equatable {
    let id = UUID()
    var text: String
    let isUser: Bool
    let timestamp: Date
}

struct ContentView: View {
    @State private var userInput = ""  // State variable for user input
    @State private var conversationHistory = [Message]() // Array to store chat history
    @State private var editingMessage: Message? // Message being edited
    @State private var backgroundColor = Color.white // Background color state
    @State private var textSize: CGFloat = 14 // Text size state
    @State private var isBold = false // Text style state
    @State private var isItalic = false // Text style state
    @State private var textAlignment: TextAlignment = .leading // Text alignment state

    var body: some View {
        VStack {
            // Display chat history
            ScrollView {
                ForEach(conversationHistory) { message in
                    VStack(alignment: message.isUser ? .trailing : .leading, spacing: 5) {
                        HStack {
                            if message.isUser {
                                Spacer()
                            }
                            Text(message.text)
                                .padding()
                                .background(message.isUser ? Color.blue.opacity(0.7) : Color.gray.opacity(0.7))
                                .foregroundColor(.white)
                                .cornerRadius(15)
                                .contextMenu {
                                    Button(action: {
                                        UIPasteboard.general.string = message.text
                                    }) {
                                        Label("Copy", systemImage: "doc.on.doc")
                                    }
                                    if message.isUser {
                                        Button(action: {
                                            editingMessage = message
                                            userInput = message.text
                                        }) {
                                            Label("Edit", systemImage: "pencil")
                                        }
                                        Button(action: {
                                            withAnimation {
                                                conversationHistory.removeAll { $0.id == message.id }
                                            }
                                        }) {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    }
                                }
                            if !message.isUser {
                                Spacer()
                            }
                        }
                        Text(message.timestamp, style: .time)
                            .font(.footnote)
                            .foregroundColor(.gray)
                    }
                    .padding(message.isUser ? .leading : .trailing, 60)
                    .padding(.vertical, 2)
                }
            }
            .background(backgroundColor)
            .textCase(isBold ? .uppercase : .lowercase)
            .font(isItalic ? .system(size: textSize, weight: .bold, design: .default).italic() : .system(size: textSize))
            .multilineTextAlignment(textAlignment)

            // Text field for user input
            HStack {
                TextField("Enter your message", text: $userInput)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding()
                Button(action: {
                    Task {
                        guard !userInput.isEmpty else { return }
                        if let editingMessage = editingMessage {
                            if let index = conversationHistory.firstIndex(where: { $0.id == editingMessage.id }) {
                                conversationHistory[index].text = userInput
                            }
                            self.editingMessage = nil
                        } else {
                            let userMessage = Message(text: userInput, isUser: true, timestamp: Date())
                            withAnimation {
                                conversationHistory.append(userMessage) // Add user input to history
                            }
                            let responseText = try? await sendUserMessage(userInput)
                            let botMessage = Message(text: responseText ?? "No response received", isUser: false, timestamp: Date())
                            withAnimation {
                                conversationHistory.append(botMessage)
                            }
                        }
                        userInput = "" // Clear input field for next message
                    }
                }) {
                    Image(systemName: "paperplane.fill")
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.blue)
                        .clipShape(Circle())
                }
                .padding(.trailing)
            }
            .padding(.bottom, 10)

            // Customization options
            VStack {
                HStack {
                    Button(action: {
                        backgroundColor = .yellow
                    }) {
                        Text("Background Yellow")
                            .padding()
                            .background(Color.yellow)
                            .cornerRadius(8)
                            .foregroundColor(.black)
                    }
                    Button(action: {
                        backgroundColor = .white
                    }) {
                        Text("Background White")
                            .padding()
                            .background(Color.white)
                            .cornerRadius(8)
                            .foregroundColor(.black)
                    }
                }
                HStack {
                    Slider(value: $textSize, in: 10...24, step: 1) {
                        Text("Text Size")
                    }
                    .padding()
                    Toggle("Bold", isOn: $isBold)
                        .padding()
                    Toggle("Italic", isOn: $isItalic)
                        .padding()
                }
                HStack {
                    Button(action: {
                        textAlignment = .leading
                    }) {
                        Text("Align Left")
                            .padding()
                            .background(Color.gray.opacity(0.3))
                            .cornerRadius(8)
                    }
                    Button(action: {
                        textAlignment = .center
                    }) {
                        Text("Align Center")
                            .padding()
                            .background(Color.gray.opacity(0.3))
                            .cornerRadius(8)
                    }
                    Button(action: {
                        textAlignment = .trailing
                    }) {
                        Text("Align Right")
                            .padding()
                            .background(Color.gray.opacity(0.3))
                            .cornerRadius(8)
                    }
                }
                HStack {
                    Button(action: {
                        saveConversation()
                    }) {
                        Text("Save Conversation")
                            .padding()
                            .background(Color.green)
                            .cornerRadius(8)
                            .foregroundColor(.white)
                    }
                    Button(action: {
                        loadConversation()
                    }) {
                        Text("Load Conversation")
                            .padding()
                            .background(Color.orange)
                            .cornerRadius(8)
                            .foregroundColor(.white)
                    }
                    Button(action: {
                        withAnimation {
                            conversationHistory.removeAll()
                        }
                    }) {
                        Text("Clear Chat")
                            .padding()
                            .background(Color.red)
                            .cornerRadius(8)
                            .foregroundColor(.white)
                    }
                }
            }
            .padding()
        }
        .padding()
        .onAppear { // Start chat on view appearance
            startChat()
        }
    }

    func saveConversation() {
        // Implement saving conversation to a file
        // This is a placeholder function
    }

    func loadConversation() {
        // Implement loading conversation from a file
        // This is a placeholder function
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: ContentView {
        ContentView()
    }
}
