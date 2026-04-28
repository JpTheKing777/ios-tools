import SwiftUI
import CoreBluetooth

class BluetoothScanner: NSObject, ObservableObject, CBCentralManagerDelegate {
    @Published var devices: [String] = []
    var centralManager: CBCentralManager!

    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn {
            centralManager.scanForPeripherals(withServices: nil, options: nil)
        }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any], rssi RSSI: NSNumber) {
        let name = peripheral.name ?? "Unknown Device"
        let entry = "\(name) — Signal: \(RSSI) dBm"
        if !devices.contains(entry) {
            devices.append(entry)
        }
    }
}

struct BluetoothView: View {
    @StateObject var scanner = BluetoothScanner()

    var body: some View {
        NavigationView {
            List(scanner.devices, id: \.self) { device in
                Text(device)
            }
            .navigationTitle("Bluetooth Scanner")
            .overlay {
                if scanner.devices.isEmpty {
                    Text("Scanning for devices...")
                        .foregroundColor(.gray)
                }
            }
        }
    }
}