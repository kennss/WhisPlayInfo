//
//  File:      SystemSampler.swift
//  Created:   2026-06-08
//  Updated:   2026-06-14
//  Developer: Kennt Kim / Calida Lab
//  Overview:  Aggregates every SiliconScopeCore sampler into one SystemSnapshot. Intended
//             to run on a single background thread driven by the UI's refresh loop.
//  Notes:     @unchecked Sendable: the underlying samplers hold non-Sendable IOReport
//             handles, but SiliconScope only ever calls sample() from one serial background
//             task, so this is safe. Do not call sample() concurrently.
//
import Foundation

public final class SystemSampler: @unchecked Sendable {
    private let power = PowerSampler()
    private let cpu = CPUSampler()
    private let gpu: GPUSampler?
    private let bandwidth = BandwidthSampler()
    private let memory = MemorySampler()
    private let thermal = ThermalSampler()
    private let temperature: TemperatureSampler
    private let network = NetworkSampler()
    private let disk = DiskSampler()
    private let battery = BatterySampler()
    private let processes = ProcessSampler()

    public init() {
        let topology = cpu?.topology
        gpu = topology.flatMap { GPUSampler(topology: $0) }
        let coreCount = topology.map { $0.eCoreCount + $0.pCoreCount } ?? 0
        temperature = TemperatureSampler(coreCount: coreCount)
    }

    public var topology: CPUTopology? { cpu?.topology }

    /// Produces one full snapshot. The IOReport samplers each sleep `interval`
    /// internally, so this blocks for roughly 3 * interval — call it off the main thread.
    public func sample(interval: TimeInterval = 0.2) -> SystemSnapshot {
        var snapshot = SystemSnapshot()
        snapshot.power = power?.sample(interval: interval) ?? PowerSample()
        snapshot.cpu = cpu?.sample(interval: interval) ?? CPUSample()
        snapshot.gpu = gpu?.sample(interval: interval) ?? GPUSample()
        snapshot.bandwidth = bandwidth?.sample(interval: interval) ?? BandwidthSample()
        snapshot.memory = memory.sample()
        snapshot.thermal = thermal.sample()
        snapshot.temperature = temperature.sample()
        snapshot.network = network.sample()
        snapshot.disk = disk.sample()
        snapshot.battery = battery.sample()
        snapshot.processes = processes.sample()   // full set; UI sorts/filters/limits
        return snapshot
    }
}
