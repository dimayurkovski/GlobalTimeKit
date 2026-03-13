//
//  MonotonicClock.swift
//  GlobalTimeKit
//
//  Created by Dmitry Yurkovski on 11/03/2026.
//

import Foundation

/// Provides monotonic uptime that is immune to manual clock changes.
///
/// Uses `clock_gettime(CLOCK_MONOTONIC_RAW)` which ticks continuously
/// regardless of system time adjustments by the user or NTP. This ensures
/// that elapsed-time calculations remain stable between sync calls.
internal enum MonotonicClock: Sendable {

    /// Returns the system's monotonic uptime in seconds.
    ///
    /// This value only increases and is not affected by the user
    /// changing the device's date/time settings.
    ///
    /// - Returns: Seconds since an arbitrary fixed point (system boot).
    static func uptime() -> TimeInterval {
        var time = timespec()
        clock_gettime(CLOCK_MONOTONIC_RAW, &time)
        return TimeInterval(time.tv_sec) + TimeInterval(time.tv_nsec) / 1_000_000_000
    }
}
