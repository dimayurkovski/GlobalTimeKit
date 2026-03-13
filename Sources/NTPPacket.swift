//
//  NTPPacket.swift
//  GlobalTimeKit
//
//  Created by Dmitry Yurkovski on 11/03/2026.
//

import Foundation

/// A 48-byte NTP v4 packet structure for encoding client requests
/// and decoding server responses.
///
/// NTP timestamps use a 64-bit format: 32 bits for seconds and 32 bits
/// for the fractional part. The epoch is January 1, 1900 (unlike Unix
/// which uses January 1, 1970).
///
/// ## Offset Calculation
///
/// ```
/// T1 = originTime      (client sent request)
/// T2 = receiveTime     (server received request)
/// T3 = transmitTime    (server sent response)
/// T4 = destinationTime (client received response)
///
/// offset = ((T2 - T1) + (T3 - T4)) / 2
/// delay  = (T4 - T1) - (T3 - T2)
/// ```
internal struct NTPPacket: Sendable {

    /// Byte 0: Leap Indicator (2 bits) | Version Number (3 bits) | Mode (3 bits).
    let flags: UInt8

    /// Stratum level of the time source (1 = primary, 2+ = secondary).
    let stratum: UInt8

    /// Maximum interval between successive messages, in log₂ seconds.
    let poll: UInt8

    /// Precision of the system clock, in log₂ seconds.
    let precision: Int8

    /// Total round-trip delay to the reference clock, in NTP short format.
    let rootDelay: UInt32

    /// Maximum error relative to the reference clock, in NTP short format.
    let rootDispersion: UInt32

    /// Reference identifier (e.g. server IP or clock source).
    let referenceID: UInt32

    /// Time when the system clock was last set or corrected (NTP 64-bit timestamp).
    let referenceTime: UInt64

    /// T1 — client transmit timestamp, copied back by the server (NTP 64-bit timestamp).
    let originTime: UInt64

    /// T2 — server receive timestamp (NTP 64-bit timestamp).
    let receiveTime: UInt64

    /// T3 — server transmit timestamp (NTP 64-bit timestamp).
    let transmitTime: UInt64

    // MARK: - Constants

    /// Seconds between NTP epoch (Jan 1, 1900) and Unix epoch (Jan 1, 1970).
    static let ntpEpochOffset: TimeInterval = 2_208_988_800

    /// NTP packet size in bytes.
    static let packetSize = 48

    // MARK: - Factory

    /// Creates a client request packet with NTP v4, mode 3 (client),
    /// and the current time as the transmit timestamp.
    ///
    /// - Parameter transmitTime: The client transmit time (T1) as a `TimeInterval`
    ///   since Unix epoch. Defaults to the current system time.
    /// - Returns: A configured `NTPPacket` ready to be encoded and sent.
    static func makeClientPacket(transmitTime: TimeInterval = Date().timeIntervalSince1970) -> NTPPacket {
        // flags: LI=0 (no warning), VN=4 (NTPv4), Mode=3 (client)
        // Binary: 00_100_011 = 0x23
        let flags: UInt8 = 0x23
        let t1 = timeIntervalToNTP(transmitTime)

        return NTPPacket(
            flags: flags,
            stratum: 0,
            poll: 0,
            precision: 0,
            rootDelay: 0,
            rootDispersion: 0,
            referenceID: 0,
            referenceTime: 0,
            originTime: 0,
            receiveTime: 0,
            transmitTime: t1
        )
    }

    // MARK: - Encode / Decode

    /// Encodes this packet into a 48-byte `Data` for sending over UDP.
    ///
    /// - Returns: A 48-byte `Data` representation of the NTP packet.
    func encode() -> Data {
        var data = Data(count: NTPPacket.packetSize)

        data[0] = flags
        data[1] = stratum
        data[2] = poll
        data[3] = UInt8(bitPattern: precision)

        data.replaceSubrange(4..<8, with: rootDelay.bigEndianBytes)
        data.replaceSubrange(8..<12, with: rootDispersion.bigEndianBytes)
        data.replaceSubrange(12..<16, with: referenceID.bigEndianBytes)
        data.replaceSubrange(16..<24, with: referenceTime.bigEndianBytes)
        data.replaceSubrange(24..<32, with: originTime.bigEndianBytes)
        data.replaceSubrange(32..<40, with: receiveTime.bigEndianBytes)
        data.replaceSubrange(40..<48, with: transmitTime.bigEndianBytes)

        return data
    }

    /// Decodes a 48-byte NTP server response into an `NTPPacket`.
    ///
    /// - Parameter data: The raw 48-byte NTP response data.
    /// - Returns: A parsed `NTPPacket`.
    /// - Throws: ``GlobalTimeError/invalidResponse`` if the data is not 48 bytes
    ///   or contains an invalid version/mode.
    static func decode(from data: Data) throws -> NTPPacket {
        guard data.count >= packetSize else {
            throw GlobalTimeError.invalidResponse
        }

        let flags = data[0]
        let version = (flags >> 3) & 0x07
        let mode = flags & 0x07

        // Accept NTP v3 or v4 responses; mode 4 = server
        guard (version == 3 || version == 4), mode == 4 else {
            throw GlobalTimeError.invalidResponse
        }

        return NTPPacket(
            flags: flags,
            stratum: data[1],
            poll: data[2],
            precision: Int8(bitPattern: data[3]),
            rootDelay: UInt32(bigEndianBytes: data, offset: 4),
            rootDispersion: UInt32(bigEndianBytes: data, offset: 8),
            referenceID: UInt32(bigEndianBytes: data, offset: 12),
            referenceTime: UInt64(bigEndianBytes: data, offset: 16),
            originTime: UInt64(bigEndianBytes: data, offset: 24),
            receiveTime: UInt64(bigEndianBytes: data, offset: 32),
            transmitTime: UInt64(bigEndianBytes: data, offset: 40)
        )
    }

    // MARK: - Timestamp Conversion

    /// Converts a 64-bit NTP timestamp to a Unix `TimeInterval` (seconds since 1970).
    ///
    /// - Parameter ntp: The 64-bit NTP timestamp (32-bit seconds + 32-bit fraction).
    /// - Returns: Seconds since Unix epoch (January 1, 1970).
    static func ntpToTimeInterval(_ ntp: UInt64) -> TimeInterval {
        let seconds = Double(ntp >> 32)
        let fraction = Double(ntp & 0xFFFF_FFFF) / Double(UInt32.max)
        return seconds - ntpEpochOffset + fraction
    }

    /// Converts a Unix `TimeInterval` (seconds since 1970) to a 64-bit NTP timestamp.
    ///
    /// - Parameter ti: Seconds since Unix epoch (January 1, 1970).
    /// - Returns: A 64-bit NTP timestamp.
    static func timeIntervalToNTP(_ ti: TimeInterval) -> UInt64 {
        let ntpSeconds = ti + ntpEpochOffset
        let whole = UInt32(clamping: Int64(ntpSeconds))
        let fraction = UInt32((ntpSeconds - Double(whole)) * Double(UInt32.max))
        return (UInt64(whole) << 32) | UInt64(fraction)
    }
}

// MARK: - Byte Helpers

private extension UInt32 {
    var bigEndianBytes: [UInt8] {
        let be = self.bigEndian
        return withUnsafeBytes(of: be) { Array($0) }
    }

    init(bigEndianBytes data: Data, offset: Int) {
        let bytes = data[offset..<(offset + 4)]
        var value: UInt32 = 0
        _ = Swift.withUnsafeMutableBytes(of: &value) { bytes.copyBytes(to: $0) }
        self = UInt32(bigEndian: value)
    }
}

private extension UInt64 {
    var bigEndianBytes: [UInt8] {
        let be = self.bigEndian
        return withUnsafeBytes(of: be) { Array($0) }
    }

    init(bigEndianBytes data: Data, offset: Int) {
        let bytes = data[offset..<(offset + 8)]
        var value: UInt64 = 0
        _ = Swift.withUnsafeMutableBytes(of: &value) { bytes.copyBytes(to: $0) }
        self = UInt64(bigEndian: value)
    }
}
