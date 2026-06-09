//
//  File:      main.swift
//  Created:   2026-06-08
//  Updated:   2026-06-08
//  Developer: Kennt Kim / Calida Lab
//  Overview:  Verification CLI for KtopCore. Prints sudoless power + CPU samples so
//             we can confirm the data layer works in a real SwiftPM build.
//  Notes:     Run with `xcrun swift run -q ktop-cli`. Sanity ranges: idle CPU power
//             well under load; P-cores should climb toward max DVFS MHz under load.
//
import Foundation
import KtopCore

guard let power = PowerSampler() else {
    FileHandle.standardError.write(Data("ktop: failed to subscribe to IOReport (power)\n".utf8))
    exit(1)
}
let cpu = CPUSampler()
let gpu: GPUSampler? = cpu.flatMap { GPUSampler(topology: $0.topology) }

if let topo = cpu?.topology {
    print("topology: \(topo.eCoreCount)E + \(topo.pCoreCount)P")
    print("E DVFS (MHz): \(topo.eFreqsMHz.map { Int($0) })")
    print("P DVFS (MHz): \(topo.pFreqsMHz.map { Int($0) })")
}

let memory = MemorySampler()
let thermal = ThermalSampler()
let bandwidth = BandwidthSampler()
let temperature = TemperatureSampler()

print("ktop probe — 3 samples (no sudo)")
for i in 1...3 {
    let p = power.sample(interval: 0.3)
    let c = cpu?.sample(interval: 0.3) ?? CPUSample()
    let g = gpu?.sample(interval: 0.3) ?? GPUSample()
    let m = memory.sample()
    let t = thermal.sample()
    let bw = bandwidth?.sample(interval: 0.3) ?? BandwidthSample()
    let tp = temperature.sample()
    let cpuLine = String(
        format: "E %3.0f%% @ %4.0f  P %3.0f%% @ %4.0f  GPU %3.0f%% @ %4.0f MHz",
        c.eUsagePercent, c.eFreqMHz, c.pUsagePercent, c.pFreqMHz, g.usagePercent, g.freqMHz
    )
    let pwrLine = String(
        format: "| E %4.1f P %4.1f GPU %4.1f ANE %4.1f DRAM %4.1f SoC %5.1f W",
        p.eCPUWatts, p.pCPUWatts, p.gpuWatts, p.aneWatts, p.dramWatts, p.socWatts
    )
    let memLine = String(
        format: "| MEM %.1f/%.0f GB (%.0f%%) wired %.1f swap %.1f",
        m.usedGB, m.totalGB, m.usedPercent, m.wiredGB, m.swapUsedGB
    )
    let fans = t.hasFans ? t.fanRPMs.map { String(format: "%.0f", $0) }.joined(separator: "/") : "none"
    let thermLine = String(
        format: "| CPU %.0f°C (max %.0f) batt %.0f°C thermal %@ fans %@",
        tp.cpuCelsius, tp.cpuMaxCelsius, tp.batteryCelsius, t.pressure.rawValue, fans
    )
    let bwLine = String(
        format: "| BW cpu %.0f gpu %.0f media %.0f other %.0f total %.0f GB/s",
        bw.cpuGBs, bw.gpuGBs, bw.mediaGBs, bw.otherGBs, bw.totalGBs
    )
    print("#\(i)  \(cpuLine)  \(pwrLine)  \(memLine)  \(bwLine)  \(thermLine)")
}

let processes = ProcessSampler()
_ = processes.sample(top: 1)            // prime CPU% baseline
Thread.sleep(forTimeInterval: 0.5)
print("\ntop processes by CPU (no sudo):")
for p in processes.sample(top: 8) {
    print(String(format: "  %6d  %6.1f%%  %8.1f MB   %@", p.pid, p.cpuPercent, p.memoryMB, p.name))
}
