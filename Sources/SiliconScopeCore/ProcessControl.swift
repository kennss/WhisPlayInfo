//
//  File:      ProcessControl.swift
//  Created:   2026-06-08
//  Updated:   2026-06-08
//  Developer: Kennt Kim / Calida Lab
//  Overview:  Sends signals to processes (sudoless, user-owned only).
//  Notes:     terminate() sends SIGTERM (graceful), forceKill() sends SIGKILL. Both
//             return false if the OS denies it (e.g. another user's / system process).
//             Destructive — callers should confirm with the user first.
//
import Foundation

public enum ProcessControl {
    @discardableResult
    public static func terminate(pid: Int32) -> Bool {
        kill(pid, SIGTERM) == 0
    }

    @discardableResult
    public static func forceKill(pid: Int32) -> Bool {
        kill(pid, SIGKILL) == 0
    }
}
