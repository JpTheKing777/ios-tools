class AIChat: ObservableObject {
    @Published var messages: [Message] = []
    @Published var isLoading = false
    private let motion = CMMotionManager()
    private let monitor = NWPathMonitor()
    private var networkStatus = "Unknown"
    private var isWifi = false
    private var isCellular = false
    private var isExpensive = false
    private var ipv4 = false
    private var ipv6 = false
    private var accelX = 0.0, accelY = 0.0, accelZ = 0.0
    private var gyroX = 0.0, gyroY = 0.0, gyroZ = 0.0
    private var magnetX = 0.0, magnetY = 0.0, magnetZ = 0.0
    private var pitch = 0.0, roll = 0.0, yaw = 0.0
    private var pressure = 0.0
    let apiKey = "YOUR_GROQ_KEY_HERE"

    init() {
        startSensors()
    }

    func startSensors() {
        // Accelerometer
        if motion.isAccelerometerAvailable {
            motion.accelerometerUpdateInterval = 0.5
            motion.startAccelerometerUpdates(to: .main) { data, _ in
                guard let data = data else { return }
                self.accelX = data.acceleration.x
                self.accelY = data.acceleration.y
                self.accelZ = data.acceleration.z
            }
        }
        // Gyroscope
        if motion.isGyroAvailable {
            motion.gyroUpdateInterval = 0.5
            motion.startGyroUpdates(to: .main) { data, _ in
                guard let data = data else { return }
                self.gyroX = data.rotationRate.x
                self.gyroY = data.rotationRate.y
                self.gyroZ = data.rotationRate.z
            }
        }
        // Magnetometer
        if motion.isMagnetometerAvailable {
            motion.magnetometerUpdateInterval = 0.5
            motion.startMagnetometerUpdates(to: .main) { data, _ in
                guard let data = data else { return }
                self.magnetX = data.magneticField.x
                self.magnetY = data.magneticField.y
                self.magnetZ = data.magneticField.z
            }
        }
        // Device motion (pitch, roll, yaw)
        if motion.isDeviceMotionAvailable {
            motion.deviceMotionUpdateInterval = 0.5
            motion.startDeviceMotionUpdates(to: .main) { data, _ in
                guard let data = data else { return }
                self.pitch = data.attitude.pitch
                self.roll = data.attitude.roll
                self.yaw = data.attitude.yaw
            }
        }
        // Altimeter/Barometer
        if #available(iOS 15.0, *) {
            let altimeter = CMAltimeter()
            if CMAltimeter.isRelativeAltitudeAvailable() {
                altimeter.startRelativeAltitudeUpdates(to: .main) { data, _ in
                    guard let data = data else { return }
                    self.pressure = data.pressure.doubleValue
                }
            }
        }
        // Network
        monitor.pathUpdateHandler = { path in
            self.networkStatus = path.status == .satisfied ? "Connected" : "Disconnected"
            self.isWifi = path.usesInterfaceType(.wifi)
            self.isCellular = path.usesInterfaceType(.cellular)
            self.isExpensive = path.isExpensive
            self.ipv4 = path.supportsIPv4
            self.ipv6 = path.supportsIPv6
        }
        monitor.start(queue: DispatchQueue.global())
    }

    func sendMessage(_ text: String) {
        messages.append(Message(role: "user", content: text))
        isLoading = true

        let sensorContext = """
        Live device data from Jay'sTools-IOS:

        ACCELEROMETER:
        - X: \(String(format: "%.4f", accelX)) g
        - Y: \(String(format: "%.4f", accelY)) g
        - Z: \(String(format: "%.4f", accelZ)) g

        GYROSCOPE:
        - X: \(String(format: "%.4f", gyroX)) rad/s
        - Y: \(String(format: "%.4f", gyroY)) rad/s
        - Z: \(String(format: "%.4f", gyroZ)) rad/s

        MAGNETOMETER:
        - X: \(String(format: "%.2f", magnetX)) µT
        - Y: \(String(format: "%.2f", magnetY)) µT
        - Z: \(String(format: "%.2f", magnetZ)) µT

        DEVICE ORIENTATION:
        - Pitch: \(String(format: "%.4f", pitch)) rad
        - Roll: \(String(format: "%.4f", roll)) rad
        - Yaw: \(String(format: "%.4f", yaw)) rad

        BAROMETER:
        - Pressure: \(String(format: "%.2f", pressure)) kPa

        NETWORK:
        - Status: \(networkStatus)
        - Wi-Fi: \(isWifi ? "Yes" : "No")
        - Cellular: \(isCellular ? "Yes" : "No")
        - Expensive connection: \(isExpensive ? "Yes" : "No")
        - IPv4: \(ipv4 ? "Supported" : "No")
        - IPv6: \(ipv6 ? "Supported" : "No")
        """

        let systemPrompt = """
        You are a helpful assistant built into an iOS tools app called Jay'sTools-IOS.
        You have access to the user's live device sensor data updated every 0.5 seconds:
        \(sensorContext)
        Answer questions about this data or anything else the user asks.
        When asked about sensor data, explain what the values mean in plain English.
        Be concise and friendly.
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