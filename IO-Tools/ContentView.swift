import SwiftUI
import Network

struct NetworkInfo: Identifiable {
    let id = UUID()
    let label: String
    let value: String
}

class NetworkScanner: ObservableObject {
    @Published var info: [NetworkInfo] = []
    private let monitor = NWPathMonitor()

    init() {
        startMonitoring()
    }

    func startMonitoring() {
        monitor.pathUpdateHandler = { path in
            DispatchQueue.main.async {
                self.info = [
                    NetworkInfo(label: "Status", value: path.status == .satisfied ? "Connected" : "Disconnected"),
                    NetworkInfo(label: "Wi-Fi", value: path.usesInterfaceType(.wifi) ? "Yes" : "No"),
                    NetworkInfo(label: "Cellular", value: path.usesInterfaceType(.cellular) ? "Yes" : "No"),
                    NetworkInfo(label: "Expensive", value: path.isExpensive ? "Yes" : "No"),
                    NetworkInfo(label: "Constrained", value: path.isConstrained ? "Yes" : "No"),
                    NetworkInfo(label: "DNS", value: path.supportsDNS ? "Supported" : "Not Supported"),
                    NetworkInfo(label: "IPv4", value: path.supportsIPv4 ? "Supported" : "Not Supported"),
                    NetworkInfo(label: "IPv6", value: path.supportsIPv6 ? "Supported" : "Not Supported"),
                ]
            }
        }
        monitor.start(queue: DispatchQueue.global())
    }
}

struct ContentView: View {
    @StateObject var scanner = NetworkScanner()

    var body: some View {
        NavigationView {
            List(scanner.info) { item in
                HStack {
                    Text(item.label)
                        .fontWeight(.semibold)
                    Spacer()
                    Text(item.value)
                        .foregroundColor(.gray)
                }
            }
            .navigationTitle("Network Scanner")
        }
    }
}