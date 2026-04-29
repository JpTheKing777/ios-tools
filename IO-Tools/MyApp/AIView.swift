import SwiftUI
import CoreMotion
import Network

struct Message: Identifiable {
    let id = UUID()
    let role: String
    let content: String
}

class AIChat: ObservableObject {
    @Published var messages: [Message] = []
    @Published var isLoading = false
    private let motion = CMMotionManager()
    private let monitor = NWPathMonitor()
    private var networkStatus = "Unknown"
    private var accelX = 0.0, accelY = 0.0, accelZ = 0.0
    let apiKey = "YOUR_GROQ_KEY_HERE"

    init() {
        startSensors()
    }

    func startSensors() {
        if motion.isAccelerometerAvailable {
            motion.accelerometerUpdateInterval = 0.5
            motion.startAccelerometerUpdates(to: .main) { data, _ in
                guard let data = data else { return }
                self.accelX = data.acceleration.x
                self.accelY = data.acceleration.y
                self.accelZ = data.acceleration.z
            }
        }
        monitor.pathUpdateHandler = { path in
            self.networkStatus = path.status == .satisfied ? "Connected" : "Disconnected"
        }
        monitor.start(queue: DispatchQueue.global())
    }

    func sendMessage(_ text: String) {
        messages.append(Message(role: "user", content: text))
        isLoading = true

        let sensorContext = """
        Current device sensor data:
        - Accelerometer: X=\(String(format: "%.3f", accelX)), Y=\(String(format: "%.3f", accelY)), Z=\(String(format: "%.3f", accelZ))
        - Network Status: \(networkStatus)
        """

        let systemPrompt = """
        You are a helpful assistant built into an iOS tools app called Jay'sTools-IOS.
        You have access to the user's live device sensor data:
        \(sensorContext)
        Answer questions about this data or anything else the user asks. Be concise and friendly.
        """

        var allMessages: [[String: Any]] = [
            ["role": "system", "content": systemPrompt]
        ]
        allMessages += messages.map { ["role": $0.role, "content": $0.content] }

        let body: [String: Any] = [
            "model": "llama-3.3-70b-versatile",
            "max_tokens": 1000,
            "messages": allMessages
        ]

        guard let url = URL(string: "https://api.groq.com/openai/v1/chat/completions"),
              let jsonData = try? JSONSerialization.data(withJSONObject: body) else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = jsonData
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        URLSession.shared.dataTask(with: request) { data, _, _ in
            DispatchQueue.main.async {
                self.isLoading = false
                guard let data = data else {
                    self.messages.append(Message(role: "assistant", content: "Error: No data received."))
                    return
                }
                let rawResponse = String(data: data, encoding: .utf8) ?? "unreadable"
                guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let choices = json["choices"] as? [[String: Any]],
                      let message = choices.first?["message"] as? [String: Any],
                      let text = message["content"] as? String else {
                    self.messages.append(Message(role: "assistant", content: "Error: \(rawResponse)"))
                    return
                }
                self.messages.append(Message(role: "assistant", content: text))
            }
        }.resume()
    }
}

struct AIView: View {
    @StateObject var chat = AIChat()
    @State private var input = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        NavigationView {
            VStack {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 12) {
                            ForEach(chat.messages) { message in
                                HStack {
                                    if message.role == "user" { Spacer() }
                                    Text(message.content)
                                        .padding(12)
                                        .background(message.role == "user" ? Color.blue : Color(.systemGray5))
                                        .foregroundColor(message.role == "user" ? .white : .primary)
                                        .cornerRadius(16)
                                        .frame(maxWidth: 280, alignment: message.role == "user" ? .trailing : .leading)
                                    if message.role == "assistant" { Spacer() }
                                }
                                .id(message.id)
                            }
                            if chat.isLoading {
                                HStack {
                                    ProgressView()
                                        .padding(12)
                                        .background(Color(.systemGray5))
                                        .cornerRadius(16)
                                    Spacer()
                                }
                            }
                        }
                        .padding()
                    }
                    .onTapGesture {
                        isFocused = false
                    }
                    .onChange(of: chat.messages.count) { _ in
                        if let last = chat.messages.last {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }

                HStack {
                    TextField("Ask about your device data...", text: $input)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .focused($isFocused)
                        .submitLabel(.send)
                        .onSubmit { send() }
                    Button(action: send) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 32))
                            .foregroundColor(input.isEmpty ? .gray : .blue)
                    }
                    .disabled(input.isEmpty || chat.isLoading)
                }
                .padding()
            }
            .navigationTitle("AI Assistant")
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        isFocused = false
                    }
                }
            }
        }
    }

    func send() {
        guard !input.isEmpty else { return }
        let text = input
        input = ""
        isFocused = false
        chat.sendMessage(text)
    }
}