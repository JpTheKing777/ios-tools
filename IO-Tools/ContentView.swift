import SwiftUI
import CoreMotion

struct ContentView: View {
    let motion = CMMotionManager()
    @State private var accelX = 0.0
    @State private var accelY = 0.0
    @State private var accelZ = 0.0
    @State private var gyroX = 0.0
    @State private var gyroY = 0.0
    @State private var gyroZ = 0.0

    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Accelerometer")) {
                    Text("X: \(accelX, specifier: "%.4f")")
                    Text("Y: \(accelY, specifier: "%.4f")")
                    Text("Z: \(accelZ, specifier: "%.4f")")
                }
                Section(header: Text("Gyroscope")) {
                    Text("X: \(gyroX, specifier: "%.4f")")
                    Text("Y: \(gyroY, specifier: "%.4f")")
                    Text("Z: \(gyroZ, specifier: "%.4f")")
                }
            }
            .navigationTitle("Sensor Dashboard")
            .onAppear { startSensors() }
            .onDisappear { stopSensors() }
        }
    }

    func startSensors() {
        if motion.isAccelerometerAvailable {
            motion.accelerometerUpdateInterval = 0.1
            motion.startAccelerometerUpdates(to: .main) { data, _ in
                guard let data = data else { return }
                accelX = data.acceleration.x
                accelY = data.acceleration.y
                accelZ = data.acceleration.z
            }
        }
        if motion.isGyroAvailable {
            motion.gyroUpdateInterval = 0.1
            motion.startGyroUpdates(to: .main) { data, _ in
                guard let data = data else { return }
                gyroX = data.rotationRate.x
                gyroY = data.rotationRate.y
                gyroZ = data.rotationRate.z
            }
        }
    }

    func stopSensors() {
        motion.stopAccelerometerUpdates()
        motion.stopGyroUpdates()
    }
}