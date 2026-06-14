//
//  File:      MenuBarView.swift
//  Created:   2026-06-08
//  Updated:   2026-06-14
//  Developer: Kennt Kim / Calida Lab
//  Overview:  Compact menu-bar popover content: the essentials at a glance (E/P, mem,
//             GPU, bandwidth, power, die temp) plus Quit.
//  Notes:     Shares the same SiliconScopeMonitor as the full window, so both stay in sync.
//
import SwiftUI
import AppKit
import SiliconScopeCore

struct MenuBarView: View {
    let monitor: SiliconScopeMonitor
    @AppStorage("temperatureFahrenheit") private var fahrenheit = false
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        let snapshot = monitor.snapshot
        VStack(alignment: .leading, spacing: 9) {
            Text("SiliconScope")
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundStyle(Theme.accent)

            Bar(label: "E", value: snapshot.cpu.eUsage,
                detail: String(format: "%.0f%%", snapshot.cpu.eUsagePercent))
            Bar(label: "P", value: snapshot.cpu.pUsage,
                detail: String(format: "%.0f%%", snapshot.cpu.pUsagePercent))
            Bar(label: "MEM", value: snapshot.memory.usedFraction,
                detail: String(format: "%.0f%%", snapshot.memory.usedPercent))

            Divider()
            KV(key: "GPU", value: String(format: "%.0f%% · %.1f W", snapshot.gpu.usagePercent, snapshot.power.gpuWatts))
            KV(key: "ANE", value: String(format: "%.1f W", snapshot.power.aneWatts))
            KV(key: "Media", value: String(format: "%.1f GB/s", snapshot.bandwidth.mediaGBs))
            KV(key: "Mem BW", value: String(format: "%.0f GB/s", snapshot.bandwidth.totalGBs))
            KV(key: "SoC power", value: String(format: "%.1f W", snapshot.power.socWatts))
            KV(key: "CPU temp", value: formatTemperature(snapshot.temperature.cpuCelsius, fahrenheit: fahrenheit))
            if snapshot.temperature.hasBattery {
                KV(key: "Battery", value: formatTemperature(snapshot.temperature.batteryCelsius, fahrenheit: fahrenheit))
            }

            Divider()
            HStack {
                Button("Settings…") { openSettings() }
                Spacer()
                Button("Quit SiliconScope") { NSApplication.shared.terminate(nil) }
            }
            .font(.system(size: 12))
        }
        .padding(14)
        .frame(width: 270)
        .background(Theme.bg)
        .foregroundStyle(Theme.text)
    }
}
