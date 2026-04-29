import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            SensorView()
                .tabItem {
                    Label("Sensors", systemImage: "gyroscope")
                }
            BluetoothView()
                .tabItem {
                    Label("Bluetooth", systemImage: "bluetooth")
                }
            NetworkView()
                .tabItem {
                    Label("Network", systemImage: "wifi")
                }
            AIView()
                .tabItem {
                    Label("AI", systemImage: "brain")
                }
        }
    }
}