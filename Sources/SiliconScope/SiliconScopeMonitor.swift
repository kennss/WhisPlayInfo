//
//  File:      SiliconScopeMonitor.swift
//  Created:   2026-06-08
//  Updated:   2026-06-14
//  Developer: Kennt Kim / Calida Lab
//  Overview:  Observable view-model that drives the UI. Polls SystemSampler on a
//             background task ~once per second and publishes the latest snapshot plus
//             a short SoC-power history for sparklines.
//  Notes:     Sampling runs via Task.detached (off main); SystemSampler is
//             @unchecked Sendable and only touched there. UI reads snapshot on main.
//
import Foundation
import Observation
import SiliconScopeCore

@MainActor
@Observable
final class SiliconScopeMonitor {
    /// Rolling time-series for sparklines (last ~60 samples per series).
    struct History {
        var soc: [Double] = []
        var pCPU: [Double] = []        // 0...1
        var gpu: [Double] = []         // 0...1
        var bandwidth: [Double] = []   // GB/s
        var dieTemp: [Double] = []     // Celsius
        var memory: [Double] = []      // GB used
        var netDown: [Double] = []     // bytes/s
        var netUp: [Double] = []       // bytes/s
        var diskRead: [Double] = []    // bytes/s
        var diskWrite: [Double] = []   // bytes/s

        mutating func push(_ s: SystemSnapshot) {
            roll(&soc, s.power.socWatts)
            roll(&pCPU, s.cpu.pUsage)
            roll(&gpu, s.gpu.usage)
            roll(&bandwidth, s.bandwidth.totalGBs)
            roll(&dieTemp, s.temperature.cpuCelsius)
            roll(&memory, s.memory.usedGB)
            roll(&netDown, s.network.downloadBytesPerSec)
            roll(&netUp, s.network.uploadBytesPerSec)
            roll(&diskRead, s.disk.readBytesPerSec)
            roll(&diskWrite, s.disk.writeBytesPerSec)
        }
        private func roll(_ series: inout [Double], _ value: Double) {
            series.append(value)
            if series.count > 60 { series.removeFirst(series.count - 60) }
        }
    }

    private(set) var snapshot = SystemSnapshot()
    private(set) var history = History()
    let topology: CPUTopology?

    // Chip-agnostic bar scaling: track observed peaks instead of hardcoding per-chip
    // maxima (bandwidth and GPU max differ across M1/Pro/Max/Ultra/M2/M3/M4).
    private(set) var bandwidthPeakGBs: Double = 80
    private(set) var mediaPeakGBs: Double = 2
    private(set) var anePeakWatts: Double = 2

    private let sampler = SystemSampler()
    private var loopTask: Task<Void, Never>?

    init() {
        topology = sampler.topology
    }

    func start() {
        guard loopTask == nil else { return }
        let sampler = sampler
        loopTask = Task { [weak self] in
            while !Task.isCancelled {
                let snap = await Task.detached(priority: .utility) {
                    sampler.sample(interval: 0.2)
                }.value
                guard let self else { return }
                self.snapshot = snap
                self.bandwidthPeakGBs = max(self.bandwidthPeakGBs, snap.bandwidth.totalGBs)
                self.mediaPeakGBs = max(self.mediaPeakGBs, snap.bandwidth.mediaGBs)
                self.anePeakWatts = max(self.anePeakWatts, snap.power.aneWatts)
                self.history.push(snap)
                let interval = UserDefaults.standard.object(forKey: "refreshInterval") as? Double ?? 1.0
                try? await Task.sleep(for: .seconds(max(0.3, interval)))
            }
        }
    }

    func stop() {
        loopTask?.cancel()
        loopTask = nil
    }
}
