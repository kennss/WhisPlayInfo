//
//  File:      MemorySample.swift
//  Created:   2026-06-08
//  Updated:   2026-06-08
//  Developer: Kennt Kim / Calida Lab
//  Overview:  Unified-memory reading split into the VM categories that sum to the total
//             (Wired + Active + Compressed + Free), plus swap.
//  Notes:     used = wired + active + compressed (these add up to what the bar shows);
//             free = total - used (folds in inactive/speculative). wiredBytes includes
//             Metal/GPU allocations — a key signal for local-LLM workloads.
//
import Foundation

public struct MemorySample: Sendable, Equatable {
    public enum Pressure: String, Sendable, Equatable { case normal, warning, critical }

    public var totalBytes: UInt64 = 0
    public var wiredBytes: UInt64 = 0
    public var activeBytes: UInt64 = 0
    public var compressedBytes: UInt64 = 0
    public var swapTotalBytes: UInt64 = 0
    public var swapUsedBytes: UInt64 = 0
    public var pressure: Pressure = .normal   // macOS memory pressure level

    public init() {}

    public var usedBytes: UInt64 { wiredBytes + activeBytes + compressedBytes }
    public var freeBytes: UInt64 { totalBytes > usedBytes ? totalBytes - usedBytes : 0 }

    private static let gb = 1024.0 * 1024.0 * 1024.0
    public var totalGB: Double { Double(totalBytes) / Self.gb }
    public var usedGB: Double { Double(usedBytes) / Self.gb }
    public var wiredGB: Double { Double(wiredBytes) / Self.gb }
    public var activeGB: Double { Double(activeBytes) / Self.gb }
    public var compressedGB: Double { Double(compressedBytes) / Self.gb }
    public var freeGB: Double { Double(freeBytes) / Self.gb }
    public var swapUsedGB: Double { Double(swapUsedBytes) / Self.gb }

    public var usedFraction: Double { totalBytes > 0 ? Double(usedBytes) / Double(totalBytes) : 0 }
    public var usedPercent: Double { usedFraction * 100 }

    // Fractions of total for a stacked bar.
    public var wiredFraction: Double { totalBytes > 0 ? Double(wiredBytes) / Double(totalBytes) : 0 }
    public var activeFraction: Double { totalBytes > 0 ? Double(activeBytes) / Double(totalBytes) : 0 }
    public var compressedFraction: Double { totalBytes > 0 ? Double(compressedBytes) / Double(totalBytes) : 0 }
    public var freeFraction: Double { totalBytes > 0 ? Double(freeBytes) / Double(totalBytes) : 0 }
}
