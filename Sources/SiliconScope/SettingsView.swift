//
//  File:      SettingsView.swift
//  Created:   2026-06-08
//  Updated:   2026-06-14
//  Developer: Kennt Kim / Calida Lab
//  Overview:  Preferences window (Cmd+,). Refresh cadence and temperature unit,
//             persisted in UserDefaults via @AppStorage.
//  Notes:     Keys: "refreshInterval" (seconds), "temperatureFahrenheit" (Bool).
//             SiliconScopeMonitor reads refreshInterval each loop; temperature views read the
//             unit. Both update live without restart.
//
import SwiftUI

struct SettingsView: View {
    @AppStorage("refreshInterval") private var refreshInterval = 1.0
    @AppStorage("temperatureFahrenheit") private var fahrenheit = false

    var body: some View {
        Form {
            Picker("Refresh interval", selection: $refreshInterval) {
                Text("0.5 s").tag(0.5)
                Text("1 s").tag(1.0)
                Text("2 s").tag(2.0)
                Text("3 s").tag(3.0)
            }
            Picker("Temperature unit", selection: $fahrenheit) {
                Text("Celsius (°C)").tag(false)
                Text("Fahrenheit (°F)").tag(true)
            }
        }
        .formStyle(.grouped)
        .frame(width: 380, height: 160)
    }
}
