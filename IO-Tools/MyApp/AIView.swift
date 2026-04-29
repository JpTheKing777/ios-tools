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

        let body: [String: Any] = [
            "model": "claude-sonnet-4-20250514",
            "max_tokens": 1000,
            "system": systemPrompt,
            "messages": messages.map { ["role": $0.role, "content": $0.content] }
        ]

        guard let url = URL(string: "https://api.anthropic.com/v1/messages"),
              let jsonData = try? JSONSerialization.data(withJSONObject: body) else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = jsonData
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        URLSession.shared.dataTask(with: request) { data, _, _ in
            DispatchQueue.main.async {
                self.isLoading = false
                guard let data = data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let content = json["content"] as? [[String: Any]],
                      let text = content.first?["text"] as? String else {
                    self.messages.append(Message(role: "assistant", content: "Error getting response."))
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
                    .onChange(of: chat.messages.count) { _ in
                        if let last = chat.messages.last {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }

                HStack {
                    TextField("Ask about your device data...", text: $input)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
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
        }
    }

    func send() {
        guard !input.isEmpty else { return }
        let text = input
        input = ""
        chat.sendMessage(text)
    }
}