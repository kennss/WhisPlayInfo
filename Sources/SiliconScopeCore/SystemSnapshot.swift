//
//  File:      SystemSnapshot.swift
//  Created:   2026-06-08
//  Updated:   2026-06-14
//  Developer: Kennt Kim / Calida Lab
//  Overview:  One unified reading of every SiliconScope metric, produced by SystemSampler
//             and consumed by the UI. Pure value type (Sendable).
//  Notes:     likelyAIEngine is a heuristic hint for the AI Workload view: LLMs hit
//             GPU/Metal + memory bandwidth (ANE idle); CoreML media features hit ANE.
//
import Foundation

public struct SystemSnapshot: Sendable {
    public var power = PowerSample()
    public var cpu = CPUSample()
    public var gpu = GPUSample()
    public var memory = MemorySample()
    public var bandwidth = BandwidthSample()
    public var thermal = ThermalSample()
    public var temperature = TemperatureSample()
    public var network = NetworkSample()
    public var disk = DiskSample()
    public var battery = BatteryInfo()
    public var processes: [ProcessRow] = []

    public init() {}

    /// Heuristic: which compute engine the current workload most likely uses.
    public var likelyAIEngine: String {
        if power.aneWatts > 1.0 { return "ANE (CoreML-style)" }
        if gpu.usage > 0.25 || power.gpuWatts > 3.0 || bandwidth.gpuGBs > 20 {
            return "GPU / Metal (LLM-style)"
        }
        return "idle"
    }

    public struct Warning: Sendable, Identifiable, Equatable {
        public enum Level: Sendable, Equatable { case warning, critical }
        public let level: Level
        public let message: String
        public var id: String { message }

        public init(level: Level, message: String) {
            self.level = level
            self.message = message
        }
    }

    /// Data-level alerts (thermal, memory, swap). UI may add context-dependent ones
    /// (e.g. bandwidth-bound) that need the observed peak.
    public var warnings: [Warning] {
        var result: [Warning] = []
        switch thermal.pressure {
        case .critical: result.append(.init(level: .critical, message: "Thermal throttling — critical"))
        case .serious:  result.append(.init(level: .warning, message: "Thermal pressure — serious"))
        default: break
        }
        switch memory.pressure {
        case .critical: result.append(.init(level: .critical, message: "Memory pressure: critical"))
        case .warning:  result.append(.init(level: .warning, message: "Memory pressure: elevated"))
        case .normal:   break
        }
        return result
    }
}
