//
//  File:      ProcessSampler.swift
//  Created:   2026-06-08
//  Updated:   2026-06-08
//  Developer: Kennt Kim / Calida Lab
//  Overview:  Builds the process table sudolessly via libproc. Stateful: each
//             sample() diffs cumulative CPU time against the previous call to derive
//             CPU%. Memory is resident size (RSS).
//  Notes:     proc_pidinfo(PROC_PIDTASKINFO) gives total_user+total_system (ns) and
//             resident_size. Processes the user cannot inspect are skipped. Prime
//             with one sample(), wait, then sample() again for meaningful CPU%.
//
import Foundation

public final class ProcessSampler {
    private var previousCPU: [pid_t: UInt64] = [:]
    private var previousTimeNs: UInt64 = 0

    public init() {}

    /// Returns processes sorted by CPU% (descending), capped at `count`
    /// (default: all, so the UI can re-sort/filter the full set).
    public func sample(top count: Int = .max) -> [ProcessRow] {
        let nowNs = DispatchTime.now().uptimeNanoseconds
        let wallDelta = previousTimeNs > 0 ? Double(nowNs &- previousTimeNs) : 0

        var currentCPU: [pid_t: UInt64] = [:]
        var rows: [ProcessRow] = []

        for pid in Self.allPIDs() where pid > 0 {
            guard let info = Self.taskInfo(pid) else { continue }
            let cpuNs = info.pti_total_user + info.pti_total_system
            currentCPU[pid] = cpuNs

            var cpuPercent = 0.0
            if let prev = previousCPU[pid], wallDelta > 0, cpuNs >= prev {
                cpuPercent = Double(cpuNs - prev) / wallDelta * 100.0
            }

            rows.append(ProcessRow(
                pid: pid,
                name: Self.name(pid),
                cpuPercent: cpuPercent,
                memoryBytes: info.pti_resident_size
            ))
        }

        previousCPU = currentCPU
        previousTimeNs = nowNs

        return Array(rows.sorted { $0.cpuPercent > $1.cpuPercent }.prefix(count))
    }

    // MARK: - libproc helpers

    private static func allPIDs() -> [pid_t] {
        let count = proc_listallpids(nil, 0)
        guard count > 0 else { return [] }
        var pids = [pid_t](repeating: 0, count: Int(count) + 64)
        let byteCount = proc_listallpids(&pids, Int32(pids.count) * Int32(MemoryLayout<pid_t>.size))
        guard byteCount > 0 else { return [] }
        let actual = Int(byteCount) / MemoryLayout<pid_t>.size
        return Array(pids.prefix(actual))
    }

    private static func taskInfo(_ pid: pid_t) -> proc_taskinfo? {
        var info = proc_taskinfo()
        let size = Int32(MemoryLayout<proc_taskinfo>.size)
        let result = proc_pidinfo(pid, PROC_PIDTASKINFO, 0, &info, size)
        return result == size ? info : nil
    }

    private static func name(_ pid: pid_t) -> String {
        var buffer = [CChar](repeating: 0, count: 256)
        let length = proc_name(pid, &buffer, UInt32(buffer.count))
        return length > 0 ? String(cString: buffer) : "pid \(pid)"
    }
}
