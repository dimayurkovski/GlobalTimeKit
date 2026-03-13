//
//  NTPResponse.swift
//  GlobalTimeKit
//
//  Created by Dmitry Yurkovski on 11/03/2026.
//

import Foundation

/// The result of an NTP query containing clock offset and timing information.
///
/// After querying an NTP server, the response provides the calculated
/// offset between the local clock and the server clock, along with
/// network round-trip timing data.
///
/// ```swift
/// let client = GlobalTimeClient()
/// try await client.sync()
/// print("Offset: \(client.offset) seconds")
/// ```
public struct NTPResponse: Sendable, CustomStringConvertible {

    /// Clock offset between the local device and the NTP server, in seconds.
    /// A positive value means the local clock is behind the server.
    /// A negative value means the local clock is ahead.
    public let offset: TimeInterval

    /// Network round-trip delay for the NTP exchange, in seconds.
    /// Lower values indicate a more reliable offset measurement.
    public let roundTripDelay: TimeInterval

    /// The corrected server time at the moment the response was received.
    /// Equivalent to `Date.now + offset`.
    public let serverTime: Date

    /// NTP stratum level of the responding server.
    /// Stratum 1 servers are directly connected to a reference clock.
    /// Stratum 2+ servers synchronize from lower stratum servers.
    public let stratum: UInt8

    public var description: String {
        "NTPResponse(offset: \(String(format: "%.4f", offset))s, delay: \(String(format: "%.4f", roundTripDelay))s, stratum: \(stratum), serverTime: \(serverTime))"
    }
}
