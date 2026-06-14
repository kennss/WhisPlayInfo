//
//  File:      GPUSample.swift
//  Created:   2026-06-08
//  Updated:   2026-06-08
//  Developer: Kennt Kim / Calida Lab
//  Overview:  Value type holding one GPU reading: utilization and average clock.
//  Notes:     usage is 0...1 (active residency fraction); freq is the
//             residency-weighted average clock in MHz. Power lives in PowerSample.
//
import Foundation

public struct GPUSample: Sendable, Equatable {
    public var usage: Double = 0       // 0...1
    public var freqMHz: Double = 0

    public init() {}

    public var usagePercent: Double { usage * 100 }
}
