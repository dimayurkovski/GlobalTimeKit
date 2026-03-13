//
//  TimeFreeze.swift
//  GlobalTimeKit
//
//  Created by Dmitry Yurkovski on 11/03/2026.
//

import Foundation

/// A snapshot of the NTP offset captured at a specific monotonic uptime.
///
/// After a successful sync, `TimeFreeze` stores the calculated offset
/// alongside the monotonic clock reading. Subsequent calls to ``now``
/// use the monotonic clock to compute the corrected time without
/// requiring another network request.
internal struct TimeFreeze: Sendable {

    /// NTP offset at the moment of synchronization (seconds).
    let offset: TimeInterval

    /// Monotonic uptime at the moment of synchronization.
    let uptime: TimeInterval

    /// Wall-clock date when the synchronization occurred.
    let timestamp: Date

    /// Returns the corrected current date using the cached offset and monotonic clock.
    ///
    /// Uses the elapsed monotonic time since sync to compute the current
    /// server-accurate timestamp, immune to manual system clock changes.
    var now: Date {
        let elapsed = MonotonicClock.uptime() - uptime
        return timestamp.addingTimeInterval(offset + elapsed)
    }
}
