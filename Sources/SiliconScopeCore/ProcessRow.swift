//
//  File:      ProcessRow.swift
//  Created:   2026-06-08
//  Updated:   2026-06-08
//  Developer: Kennt Kim / Calida Lab
//  Overview:  One row of the process table: pid, name, CPU%, resident memory.
//  Notes:     cpuPercent is summed across cores (top-style, can exceed 100). It is a
//             delta between two ProcessSampler reads, so the first read reports 0.
//
import Foundation

public struct ProcessRow: Sendable, Equatable, Identifiable {
    public let pid: Int32
    public let name: String
    public let cpuPercent: Double
    public let memoryBytes: UInt64

    public var id: Int32 { pid }

    public init(pid: Int32, name: String, cpuPercent: Double, memoryBytes: UInt64) {
        self.pid = pid
        self.name = name
        self.cpuPercent = cpuPercent
        self.memoryBytes = memoryBytes
    }

    public var memoryMB: Double { Double(memoryBytes) / (1024.0 * 1024.0) }
}
