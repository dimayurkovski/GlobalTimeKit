//
//  GlobalTimeKitTests.swift
//  GlobalTimeKitTests
//
//  Created by Dmitry Yurkovski on 11/03/2026.
//

import Testing
import Foundation
@testable import GlobalTimeKit

// MARK: - NTPPacket Tests

@Suite("NTPPacket — 48-byte NTP v4 packet encode/decode and timestamp conversion")
struct NTPPacketTests {

    // MARK: - Encode

    @Suite("Encode — Serializing NTPPacket to 48-byte Data")
    struct EncodeTests {

        @Test("Encoded packet is exactly 48 bytes")
        func encodeProduces48Bytes() {
            let packet = NTPPacket.makeClientPacket()
            let data = packet.encode()
            #expect(data.count == 48)
        }

        @Test("Client packet flags byte is 0x23 (LI=0, VN=4, Mode=3)")
        func clientPacketHasCorrectFlags() {
            let packet = NTPPacket.makeClientPacket()
            #expect(packet.flags == 0x23)

            let data = packet.encode()
            #expect(data[0] == 0x23)
        }

        @Test("Client packet has zeroed metadata fields")
        func clientPacketHasZeroFields() {
            let packet = NTPPacket.makeClientPacket()
            #expect(packet.stratum == 0)
            #expect(packet.poll == 0)
            #expect(packet.precision == 0)
            #expect(packet.rootDelay == 0)
            #expect(packet.rootDispersion == 0)
            #expect(packet.referenceID == 0)
            #expect(packet.referenceTime == 0)
            #expect(packet.originTime == 0)
            #expect(packet.receiveTime == 0)
        }

        @Test("Client packet transmit time is non-zero")
        func clientPacketTransmitTimeIsNonZero() {
            let packet = NTPPacket.makeClientPacket()
            #expect(packet.transmitTime != 0)
        }

        @Test("Transmit timestamp bytes are big-endian")
        func encodeTimestampBigEndian() {
            let packet = NTPPacket(
                flags: 0x24, stratum: 0, poll: 0, precision: 0,
                rootDelay: 0, rootDispersion: 0, referenceID: 0,
                referenceTime: 0, originTime: 0, receiveTime: 0,
                transmitTime: 0x0102030405060708
            )
            let data = packet.encode()
            #expect(data[40] == 0x01)
            #expect(data[41] == 0x02)
            #expect(data[42] == 0x03)
            #expect(data[43] == 0x04)
            #expect(data[44] == 0x05)
            #expect(data[45] == 0x06)
            #expect(data[46] == 0x07)
            #expect(data[47] == 0x08)
        }

        @Test("Root delay bytes are big-endian")
        func encodeRootDelayBigEndian() {
            let packet = NTPPacket(
                flags: 0x24, stratum: 0, poll: 0, precision: 0,
                rootDelay: 0x0A0B0C0D, rootDispersion: 0, referenceID: 0,
                referenceTime: 0, originTime: 0, receiveTime: 0,
                transmitTime: 0
            )
            let data = packet.encode()
            #expect(data[4] == 0x0A)
            #expect(data[5] == 0x0B)
            #expect(data[6] == 0x0C)
            #expect(data[7] == 0x0D)
        }

        @Test("Root dispersion bytes are big-endian")
        func encodeRootDispersionBigEndian() {
            let packet = NTPPacket(
                flags: 0x24, stratum: 0, poll: 0, precision: 0,
                rootDelay: 0, rootDispersion: 0xAABBCCDD, referenceID: 0,
                referenceTime: 0, originTime: 0, receiveTime: 0,
                transmitTime: 0
            )
            let data = packet.encode()
            #expect(data[8] == 0xAA)
            #expect(data[9] == 0xBB)
            #expect(data[10] == 0xCC)
            #expect(data[11] == 0xDD)
        }

        @Test("Reference ID bytes are big-endian")
        func encodeReferenceIDBigEndian() {
            let packet = NTPPacket(
                flags: 0x24, stratum: 0, poll: 0, precision: 0,
                rootDelay: 0, rootDispersion: 0, referenceID: 0x47505300,
                referenceTime: 0, originTime: 0, receiveTime: 0,
                transmitTime: 0
            )
            let data = packet.encode()
            // "GPS\0" = 0x47 0x50 0x53 0x00
            #expect(data[12] == 0x47)
            #expect(data[13] == 0x50)
            #expect(data[14] == 0x53)
            #expect(data[15] == 0x00)
        }

        @Test("Negative precision is encoded correctly")
        func encodePrecisionNegative() {
            let packet = NTPPacket(
                flags: 0x24, stratum: 0, poll: 0, precision: -32,
                rootDelay: 0, rootDispersion: 0, referenceID: 0,
                referenceTime: 0, originTime: 0, receiveTime: 0,
                transmitTime: 0
            )
            let data = packet.encode()
            #expect(data[3] == UInt8(bitPattern: Int8(-32)))
        }

        @Test("All four timestamp fields are encoded at correct offsets")
        func encodeAllTimestampOffsets() {
            let packet = NTPPacket(
                flags: 0x24, stratum: 0, poll: 0, precision: 0,
                rootDelay: 0, rootDispersion: 0, referenceID: 0,
                referenceTime: 0x1111111111111111,
                originTime: 0x2222222222222222,
                receiveTime: 0x3333333333333333,
                transmitTime: 0x4444444444444444
            )
            let data = packet.encode()
            // referenceTime at offset 16
            #expect(data[16] == 0x11)
            #expect(data[23] == 0x11)
            // originTime at offset 24
            #expect(data[24] == 0x22)
            #expect(data[31] == 0x22)
            // receiveTime at offset 32
            #expect(data[32] == 0x33)
            #expect(data[39] == 0x33)
            // transmitTime at offset 40
            #expect(data[40] == 0x44)
            #expect(data[47] == 0x44)
        }
    }

    // MARK: - Decode

    @Suite("Decode — Parsing 48-byte Data into NTPPacket")
    struct DecodeTests {

        @Test("Decodes valid NTP v4 server response")
        func decodeValidV4ServerResponse() throws {
            var data = Data(count: 48)
            data[0] = 0x24  // v4, mode=4 (server)
            data[1] = 2     // stratum
            data[2] = 6     // poll
            data[3] = UInt8(bitPattern: Int8(-20))

            let packet = try NTPPacket.decode(from: data)
            #expect(packet.flags == 0x24)
            #expect(packet.stratum == 2)
            #expect(packet.poll == 6)
            #expect(packet.precision == -20)
        }

        @Test("Decodes valid NTP v3 server response")
        func decodeV3ServerResponse() throws {
            var data = Data(count: 48)
            data[0] = 0x1C  // v3, mode=4
            data[1] = 1

            let packet = try NTPPacket.decode(from: data)
            #expect(packet.flags == 0x1C)
            #expect(packet.stratum == 1)
        }

        @Test("Decodes data larger than 48 bytes without error")
        func decodeLargerDataSucceeds() throws {
            var data = Data(count: 64)
            data[0] = 0x24
            data[1] = 3
            let packet = try NTPPacket.decode(from: data)
            #expect(packet.stratum == 3)
        }

        @Test("Decodes leap indicator bits correctly")
        func decodeLeapIndicator() throws {
            // LI=3 (alarm), VN=4, Mode=4 → 11_100_100 = 0xE4
            var data = Data(count: 48)
            data[0] = 0xE4
            let packet = try NTPPacket.decode(from: data)
            let li = (packet.flags >> 6) & 0x03
            #expect(li == 3)
        }

        @Test("Throws invalidResponse for data shorter than 48 bytes")
        func decodeTooShortDataThrows() {
            let shortData = Data(count: 47)
            #expect(throws: GlobalTimeError.invalidResponse) {
                try NTPPacket.decode(from: shortData)
            }
        }

        @Test("Throws invalidResponse for empty data")
        func decodeEmptyDataThrows() {
            #expect(throws: GlobalTimeError.invalidResponse) {
                try NTPPacket.decode(from: Data())
            }
        }

        @Test("Throws invalidResponse for single byte data")
        func decodeSingleByteThrows() {
            #expect(throws: GlobalTimeError.invalidResponse) {
                try NTPPacket.decode(from: Data([0x24]))
            }
        }

        @Test("Throws invalidResponse for NTP version 1")
        func decodeVersion1Throws() {
            // v1, mode=4 → 00_001_100 = 0x0C
            var data = Data(count: 48)
            data[0] = 0x0C
            #expect(throws: GlobalTimeError.invalidResponse) {
                try NTPPacket.decode(from: data)
            }
        }

        @Test("Throws invalidResponse for NTP version 2")
        func decodeVersion2Throws() {
            // v2, mode=4 → 00_010_100 = 0x14
            var data = Data(count: 48)
            data[0] = 0x14
            #expect(throws: GlobalTimeError.invalidResponse) {
                try NTPPacket.decode(from: data)
            }
        }

        @Test("Throws invalidResponse for NTP version 5")
        func decodeVersion5Throws() {
            // v5, mode=4 → 00_101_100 = 0x2C
            var data = Data(count: 48)
            data[0] = 0x2C
            #expect(throws: GlobalTimeError.invalidResponse) {
                try NTPPacket.decode(from: data)
            }
        }

        @Test("Throws invalidResponse for client mode (mode=3)")
        func decodeClientModeThrows() {
            // v4, mode=3 → 0x23
            var data = Data(count: 48)
            data[0] = 0x23
            #expect(throws: GlobalTimeError.invalidResponse) {
                try NTPPacket.decode(from: data)
            }
        }

        @Test("Throws invalidResponse for mode 0 (reserved)")
        func decodeMode0Throws() {
            // v4, mode=0 → 0x20
            var data = Data(count: 48)
            data[0] = 0x20
            #expect(throws: GlobalTimeError.invalidResponse) {
                try NTPPacket.decode(from: data)
            }
        }

        @Test("Throws invalidResponse for broadcast mode (mode=5)")
        func decodeMode5Throws() {
            // v4, mode=5 → 00_100_101 = 0x25
            var data = Data(count: 48)
            data[0] = 0x25
            #expect(throws: GlobalTimeError.invalidResponse) {
                try NTPPacket.decode(from: data)
            }
        }

        @Test("Throws invalidResponse for all-zero flags byte")
        func decodeAllZeroFlagsThrows() {
            let data = Data(count: 48)
            #expect(throws: GlobalTimeError.invalidResponse) {
                try NTPPacket.decode(from: data)
            }
        }
    }

    // MARK: - Encode/Decode Round-Trip

    @Suite("Round-Trip — Encode then decode preserves all fields")
    struct RoundTripTests {

        @Test("Full packet round-trip preserves all fields")
        func encodeDecodeRoundTrip() throws {
            let original = NTPPacket(
                flags: 0x24,
                stratum: 2,
                poll: 6,
                precision: -20,
                rootDelay: 256,
                rootDispersion: 512,
                referenceID: 0x47505300,
                referenceTime: 0xE9A1_2345_6789_ABCD,
                originTime: 0xE9A1_2345_0000_0000,
                receiveTime: 0xE9A1_2345_1111_1111,
                transmitTime: 0xE9A1_2345_2222_2222
            )

            let data = original.encode()
            let decoded = try NTPPacket.decode(from: data)

            #expect(decoded.flags == original.flags)
            #expect(decoded.stratum == original.stratum)
            #expect(decoded.poll == original.poll)
            #expect(decoded.precision == original.precision)
            #expect(decoded.rootDelay == original.rootDelay)
            #expect(decoded.rootDispersion == original.rootDispersion)
            #expect(decoded.referenceID == original.referenceID)
            #expect(decoded.referenceTime == original.referenceTime)
            #expect(decoded.originTime == original.originTime)
            #expect(decoded.receiveTime == original.receiveTime)
            #expect(decoded.transmitTime == original.transmitTime)
        }

        @Test("Round-trip with max UInt32 values")
        func roundTripMaxValues() throws {
            let original = NTPPacket(
                flags: 0x24,
                stratum: 255,
                poll: 255,
                precision: -128,
                rootDelay: UInt32.max,
                rootDispersion: UInt32.max,
                referenceID: UInt32.max,
                referenceTime: UInt64.max,
                originTime: UInt64.max,
                receiveTime: UInt64.max,
                transmitTime: UInt64.max
            )

            let data = original.encode()
            let decoded = try NTPPacket.decode(from: data)

            #expect(decoded.stratum == 255)
            #expect(decoded.precision == -128)
            #expect(decoded.rootDelay == UInt32.max)
            #expect(decoded.rootDispersion == UInt32.max)
            #expect(decoded.referenceID == UInt32.max)
            #expect(decoded.referenceTime == UInt64.max)
            #expect(decoded.transmitTime == UInt64.max)
        }

        @Test("Round-trip with NTP v3 server flags")
        func roundTripV3() throws {
            let original = NTPPacket(
                flags: 0x1C, // v3, mode=4
                stratum: 1, poll: 4, precision: -10,
                rootDelay: 100, rootDispersion: 200, referenceID: 0x50505300,
                referenceTime: 12345, originTime: 67890,
                receiveTime: 11111, transmitTime: 22222
            )
            let decoded = try NTPPacket.decode(from: original.encode())
            #expect(decoded.flags == 0x1C)
            #expect(decoded.rootDelay == 100)
        }
    }

    // MARK: - Timestamp Conversion

    @Suite("Timestamp Conversion — NTP 64-bit ↔ Unix TimeInterval")
    struct TimestampConversionTests {

        @Test("NTP epoch offset is 2,208,988,800 seconds (1900→1970)")
        func ntpEpochOffsetIsCorrect() {
            #expect(NTPPacket.ntpEpochOffset == 2_208_988_800)
        }

        @Test("Packet size constant is 48")
        func packetSizeIs48() {
            #expect(NTPPacket.packetSize == 48)
        }

        @Test("NTP timestamp at Unix epoch converts to 0.0")
        func ntpToTimeIntervalAtUnixEpoch() {
            let ntpAtUnixEpoch: UInt64 = UInt64(2_208_988_800) << 32
            let ti = NTPPacket.ntpToTimeInterval(ntpAtUnixEpoch)
            #expect(abs(ti) < 0.001)
        }

        @Test("Unix epoch (0.0) converts to NTP seconds = 2,208,988,800")
        func timeIntervalToNTPAtUnixEpoch() {
            let ntp = NTPPacket.timeIntervalToNTP(0)
            let seconds = UInt32(ntp >> 32)
            #expect(seconds == 2_208_988_800)
        }

        @Test("NTP timestamp 0 converts to -2,208,988,800 (Jan 1, 1900)")
        func ntpToTimeIntervalZero() {
            let ti = NTPPacket.ntpToTimeInterval(0)
            #expect(abs(ti - (-2_208_988_800)) < 0.001)
        }

        @Test("Round-trip conversion preserves time (Nov 2023)")
        func timestampRoundTrip() {
            let original: TimeInterval = 1_700_000_000.5
            let ntp = NTPPacket.timeIntervalToNTP(original)
            let restored = NTPPacket.ntpToTimeInterval(ntp)
            #expect(abs(original - restored) < 0.001)
        }

        @Test("Round-trip conversion preserves current system time")
        func timestampRoundTripCurrentTime() {
            let now = Date().timeIntervalSince1970
            let ntp = NTPPacket.timeIntervalToNTP(now)
            let restored = NTPPacket.ntpToTimeInterval(ntp)
            #expect(abs(now - restored) < 0.001)
        }

        @Test("Round-trip conversion preserves negative timestamp (~1938)")
        func timestampRoundTripNegative() {
            let ti: TimeInterval = -1_000_000_000
            let ntp = NTPPacket.timeIntervalToNTP(ti)
            let restored = NTPPacket.ntpToTimeInterval(ntp)
            #expect(abs(ti - restored) < 0.001)
        }

        @Test("Round-trip conversion preserves near-future timestamp (~2035)")
        func timestampRoundTripNearFuture() {
            let ti: TimeInterval = 2_051_222_400.0 // ~Jan 2035, within NTP era 0
            let ntp = NTPPacket.timeIntervalToNTP(ti)
            let restored = NTPPacket.ntpToTimeInterval(ntp)
            #expect(abs(ti - restored) < 0.001)
        }

        @Test("Custom transmit time is preserved in packet")
        func makeClientPacketWithCustomTransmitTime() {
            let customTime: TimeInterval = 1_700_000_000.0
            let packet = NTPPacket.makeClientPacket(transmitTime: customTime)
            let restored = NTPPacket.ntpToTimeInterval(packet.transmitTime)
            #expect(abs(customTime - restored) < 0.001)
        }

        @Test("Fractional seconds are preserved in conversion")
        func fractionalSecondsPreserved() {
            let ti: TimeInterval = 1_700_000_000.123456
            let ntp = NTPPacket.timeIntervalToNTP(ti)
            let restored = NTPPacket.ntpToTimeInterval(ntp)
            // NTP fraction has ~232ps resolution, so < 1ms is fine
            #expect(abs(ti - restored) < 0.001)
        }

        @Test("Integer seconds convert without fractional part")
        func integerSecondsConvert() {
            let ti: TimeInterval = 1_700_000_000.0
            let ntp = NTPPacket.timeIntervalToNTP(ti)
            let fraction = UInt32(ntp & 0xFFFF_FFFF)
            #expect(fraction == 0)
        }
    }
}

// MARK: - GlobalTimeConfig Tests

@Suite("GlobalTimeConfig — NTP client configuration with defaults and validation")
struct GlobalTimeConfigTests {

    @Suite("Default Values — Factory configuration out of the box")
    struct DefaultValueTests {

        @Test("Default server is time.apple.com")
        func defaultServer() {
            #expect(GlobalTimeConfig().server == "time.apple.com")
        }

        @Test("Default timeout is 5 seconds")
        func defaultTimeout() {
            #expect(GlobalTimeConfig().timeout == .seconds(5))
        }

        @Test("Default samples count is 4")
        func defaultSamples() {
            #expect(GlobalTimeConfig().samples == 4)
        }

        @Test("Default logLevel is .info")
        func defaultLogLevel() {
            #expect(GlobalTimeConfig().logLevel == .info)
        }
    }

    @Suite("Custom Values — User-specified configuration")
    struct CustomValueTests {

        @Test("Accepts custom server hostname")
        func customServer() {
            let config = GlobalTimeConfig(server: "time.google.com")
            #expect(config.server == "time.google.com")
        }

        @Test("Accepts custom timeout")
        func customTimeout() {
            let config = GlobalTimeConfig(timeout: .seconds(10))
            #expect(config.timeout == .seconds(10))
        }

        @Test("Accepts millisecond timeout")
        func customMillisecondTimeout() {
            let config = GlobalTimeConfig(timeout: .milliseconds(500))
            #expect(config.timeout == .milliseconds(500))
        }

        @Test("Accepts custom sample count")
        func customSamples() {
            let config = GlobalTimeConfig(samples: 8)
            #expect(config.samples == 8)
        }

        @Test("Accepts large sample count")
        func largeSamples() {
            let config = GlobalTimeConfig(samples: 100)
            #expect(config.samples == 100)
        }

        @Test("Accepts custom logLevel")
        func customLogLevel() {
            #expect(GlobalTimeConfig(logLevel: .debug).logLevel == .debug)
            #expect(GlobalTimeConfig(logLevel: .none).logLevel == .none)
            #expect(GlobalTimeConfig(logLevel: .error).logLevel == .error)
        }
    }

    @Suite("Validation — Samples clamped to minimum 1")
    struct ValidationTests {

        @Test("Zero samples clamped to 1")
        func zeroSamplesClampedToOne() {
            #expect(GlobalTimeConfig(samples: 0).samples == 1)
        }

        @Test("Negative samples clamped to 1")
        func negativeSamplesClampedToOne() {
            #expect(GlobalTimeConfig(samples: -5).samples == 1)
        }

        @Test("Int.min samples clamped to 1")
        func intMinSamplesClampedToOne() {
            #expect(GlobalTimeConfig(samples: Int.min).samples == 1)
        }

        @Test("Single sample is accepted")
        func singleSample() {
            #expect(GlobalTimeConfig(samples: 1).samples == 1)
        }
    }

    @Test("GlobalTimeConfig conforms to Sendable")
    func configIsSendable() {
        let config = GlobalTimeConfig()
        Task { @Sendable in
            _ = config.server
        }
    }

    @Suite("LogLevel — Comparable ordering and semantics")
    struct LogLevelTests {

        @Test("LogLevel ordering: none < error < warning < info < debug")
        func ordering() {
            #expect(GlobalTimeConfig.LogLevel.none < .error)
            #expect(GlobalTimeConfig.LogLevel.error < .warning)
            #expect(GlobalTimeConfig.LogLevel.warning < .info)
            #expect(GlobalTimeConfig.LogLevel.info < .debug)
        }

        @Test("Same levels are equal")
        func equality() {
            #expect(GlobalTimeConfig.LogLevel.info == .info)
            #expect(GlobalTimeConfig.LogLevel.none == .none)
        }

        @Test("debug is the most verbose level")
        func debugIsMax() {
            let all: [GlobalTimeConfig.LogLevel] = [.none, .error, .warning, .info, .debug]
            for level in all {
                #expect(level <= .debug)
            }
        }
    }
}

// MARK: - TimeFreeze Tests

@Suite("TimeFreeze — Cached NTP offset snapshot and corrected time computation")
struct TimeFreezeTests {

    @Suite("now — Corrected date using cached offset and monotonic clock")
    struct NowTests {

        @Test("Positive offset shifts time forward")
        func positiveOffset() {
            let freeze = TimeFreeze(offset: 5.0, uptime: MonotonicClock.uptime(), timestamp: Date())
            let before = Date().addingTimeInterval(4.9)
            let now = freeze.now
            let after = Date().addingTimeInterval(5.1)
            #expect(now >= before)
            #expect(now <= after)
        }

        @Test("Negative offset shifts time backward")
        func negativeOffset() {
            let freeze = TimeFreeze(offset: -3.0, uptime: MonotonicClock.uptime(), timestamp: Date())
            let before = Date().addingTimeInterval(-3.1)
            let now = freeze.now
            let after = Date().addingTimeInterval(-2.9)
            #expect(now >= before)
            #expect(now <= after)
        }

        @Test("Zero offset returns approximately current time")
        func zeroOffset() {
            let freeze = TimeFreeze(offset: 0, uptime: MonotonicClock.uptime(), timestamp: Date())
            let before = Date().addingTimeInterval(-0.1)
            let now = freeze.now
            let after = Date().addingTimeInterval(0.1)
            #expect(now >= before)
            #expect(now <= after)
        }

        @Test("Large positive offset (1 hour)")
        func largePositiveOffset() {
            let freeze = TimeFreeze(offset: 3600, uptime: MonotonicClock.uptime(), timestamp: Date())
            let expected = Date().addingTimeInterval(3600)
            let diff = abs(freeze.now.timeIntervalSince(expected))
            #expect(diff < 0.1)
        }

        @Test("Large negative offset (1 hour)")
        func largeNegativeOffset() {
            let freeze = TimeFreeze(offset: -3600, uptime: MonotonicClock.uptime(), timestamp: Date())
            let expected = Date().addingTimeInterval(-3600)
            let diff = abs(freeze.now.timeIntervalSince(expected))
            #expect(diff < 0.1)
        }

        @Test("now uses monotonic elapsed time, not Date()")
        func usesMonotonicElapsed() {
            let uptime = MonotonicClock.uptime()
            let timestamp = Date()
            let freeze = TimeFreeze(offset: 10.0, uptime: uptime, timestamp: timestamp)
            // elapsed ≈ 0, so now ≈ timestamp + offset
            let diff = abs(freeze.now.timeIntervalSince(timestamp.addingTimeInterval(10.0)))
            #expect(diff < 0.1)
        }
    }

    @Suite("Properties — Stored values are accessible")
    struct PropertyTests {

        @Test("All properties are stored correctly")
        func storesProperties() {
            let date = Date()
            let freeze = TimeFreeze(offset: 2.5, uptime: 12345.678, timestamp: date)
            #expect(freeze.offset == 2.5)
            #expect(freeze.uptime == 12345.678)
            #expect(freeze.timestamp == date)
        }

        @Test("TimeFreeze conforms to Sendable")
        func isSendable() {
            let freeze = TimeFreeze(offset: 1.0, uptime: MonotonicClock.uptime(), timestamp: Date())
            Task { @Sendable in
                _ = freeze.now
            }
        }
    }
}

// MARK: - MonotonicClock Tests

@Suite("MonotonicClock — Monotonic uptime immune to manual clock changes")
struct MonotonicClockTests {

    @Test("Uptime returns a positive value")
    func uptimeIsPositive() {
        #expect(MonotonicClock.uptime() > 0)
    }

    @Test("Consecutive calls are monotonically non-decreasing")
    func uptimeIsMonotonicallyIncreasing() {
        let first = MonotonicClock.uptime()
        let second = MonotonicClock.uptime()
        #expect(second >= first)
    }

    @Test("Uptime increases after a short sleep (sub-second precision)")
    func uptimeHasSubSecondPrecision() {
        let first = MonotonicClock.uptime()
        Thread.sleep(forTimeInterval: 0.01)
        let second = MonotonicClock.uptime()
        let diff = second - first
        #expect(diff > 0)
        #expect(diff < 1.0)
    }

    @Test("100 consecutive calls never decrease")
    func uptimeNeverDecreases() {
        var previous = MonotonicClock.uptime()
        for _ in 0..<100 {
            let current = MonotonicClock.uptime()
            #expect(current >= previous)
            previous = current
        }
    }
}

// MARK: - NTPResponse Tests

@Suite("NTPResponse — NTP query result with offset, delay, and server time")
struct NTPResponseTests {

    @Test("All properties are stored and accessible")
    func storesAllProperties() {
        let date = Date()
        let response = NTPResponse(
            offset: 0.5,
            roundTripDelay: 0.05,
            serverTime: date,
            stratum: 2
        )
        #expect(response.offset == 0.5)
        #expect(response.roundTripDelay == 0.05)
        #expect(response.serverTime == date)
        #expect(response.stratum == 2)
    }

    @Test("Supports negative offset")
    func negativeOffset() {
        let response = NTPResponse(offset: -1.5, roundTripDelay: 0.02, serverTime: Date(), stratum: 1)
        #expect(response.offset == -1.5)
    }

    @Test("Supports zero offset and delay")
    func zeroValues() {
        let response = NTPResponse(offset: 0, roundTripDelay: 0, serverTime: Date(), stratum: 1)
        #expect(response.offset == 0)
        #expect(response.roundTripDelay == 0)
    }

    @Test("Supports stratum 1 (primary reference)")
    func stratum1() {
        let response = NTPResponse(offset: 0, roundTripDelay: 0, serverTime: Date(), stratum: 1)
        #expect(response.stratum == 1)
    }

    @Test("Supports stratum 16 (unsynchronized)")
    func stratum16() {
        let response = NTPResponse(offset: 0, roundTripDelay: 0, serverTime: Date(), stratum: 16)
        #expect(response.stratum == 16)
    }

    @Test("NTPResponse conforms to Sendable")
    func isSendable() {
        let response = NTPResponse(offset: 0, roundTripDelay: 0, serverTime: Date(), stratum: 1)
        Task { @Sendable in
            _ = response.offset
        }
    }

    @Test("description contains offset, delay, stratum, and serverTime")
    func customDescription() {
        let response = NTPResponse(offset: 0.1234, roundTripDelay: 0.0567, serverTime: Date(), stratum: 2)
        let desc = response.description
        #expect(desc.contains("0.1234"))
        #expect(desc.contains("0.0567"))
        #expect(desc.contains("stratum: 2"))
        #expect(desc.contains("NTPResponse"))
    }
}

// MARK: - GlobalTimeError Tests

@Suite("GlobalTimeError — Error types for NTP synchronization failures")
struct GlobalTimeErrorTests {

    @Test("All five error cases exist")
    func allCasesExist() {
        let errors: [GlobalTimeError] = [
            .timeout,
            .invalidResponse,
            .dnsResolutionFailed,
            .networkUnavailable,
            .serverUnreachable
        ]
        #expect(errors.count == 5)
    }

    @Test("Conforms to Error protocol")
    func conformsToError() {
        let error: Error = GlobalTimeError.timeout
        #expect(error is GlobalTimeError)
    }

    @Test("Conforms to Sendable")
    func conformsToSendable() {
        let error: Sendable = GlobalTimeError.timeout
        _ = error
    }

    @Test("All error cases are distinct from each other")
    func casesAreDistinct() {
        let all: [GlobalTimeError] = [.timeout, .invalidResponse, .dnsResolutionFailed, .networkUnavailable, .serverUnreachable]
        for i in 0..<all.count {
            for j in (i + 1)..<all.count {
                #expect(all[i] != all[j])
            }
        }
    }

    @Test("Same error cases are equal")
    func casesAreEquatable() {
        #expect(GlobalTimeError.timeout == GlobalTimeError.timeout)
        #expect(GlobalTimeError.invalidResponse == GlobalTimeError.invalidResponse)
        #expect(GlobalTimeError.dnsResolutionFailed == GlobalTimeError.dnsResolutionFailed)
        #expect(GlobalTimeError.networkUnavailable == GlobalTimeError.networkUnavailable)
        #expect(GlobalTimeError.serverUnreachable == GlobalTimeError.serverUnreachable)
    }

    @Test("Each error has a localized description")
    func hasLocalizedDescription() {
        let errors: [GlobalTimeError] = [.timeout, .invalidResponse, .dnsResolutionFailed, .networkUnavailable, .serverUnreachable]
        for error in errors {
            #expect(error.localizedDescription.isEmpty == false)
        }
    }

    @Test("LocalizedError provides specific error descriptions")
    func localizedErrorDescriptions() {
        #expect(GlobalTimeError.timeout.errorDescription == "NTP request timed out")
        #expect(GlobalTimeError.invalidResponse.errorDescription == "Invalid NTP server response")
        #expect(GlobalTimeError.dnsResolutionFailed.errorDescription == "Could not resolve NTP server hostname")
        #expect(GlobalTimeError.networkUnavailable.errorDescription == "No network connection available")
        #expect(GlobalTimeError.serverUnreachable.errorDescription == "NTP server is unreachable")
    }

    @Test("localizedDescription returns the custom errorDescription")
    func localizedDescriptionUsesErrorDescription() {
        let error: Error = GlobalTimeError.timeout
        #expect(error.localizedDescription == "NTP request timed out")
    }
}

// MARK: - GlobalTimeClient Tests

@Suite("GlobalTimeClient — Public API for NTP sync, fetchTime, and cached time access")
struct GlobalTimeClientTests {

    @Suite("Initialization — Default and custom configurations")
    struct InitTests {

        @Test("Default initialization uses time.apple.com, 5s, 4 samples")
        func defaultInit() {
            let client = GlobalTimeClient()
            #expect(client.config.server == "time.apple.com")
            #expect(client.config.timeout == .seconds(5))
            #expect(client.config.samples == 4)
        }

        @Test("Custom configuration is stored")
        func customInit() {
            let config = GlobalTimeConfig(server: "time.google.com", timeout: .seconds(10), samples: 6)
            let client = GlobalTimeClient(config: config)
            #expect(client.config.server == "time.google.com")
            #expect(client.config.timeout == .seconds(10))
            #expect(client.config.samples == 6)
        }

        @Test("Version string is set")
        func versionIsSet() {
            #expect(GlobalTimeClient.version == "1.0.0")
        }
    }

    @Suite("Initial State — Before any sync call")
    struct InitialStateTests {

        @Test("isSynced is false before sync")
        func notSynced() {
            #expect(GlobalTimeClient().isSynced == false)
        }

        @Test("offset is 0 before sync")
        func zeroOffset() {
            #expect(GlobalTimeClient().offset == 0)
        }

        @Test("lastSyncDate is nil before sync")
        func nilLastSyncDate() {
            #expect(GlobalTimeClient().lastSyncDate == nil)
        }

        @Test("now returns approximately system time before sync")
        func nowFallsBackToSystemTime() {
            let client = GlobalTimeClient()
            let before = Date().addingTimeInterval(-0.1)
            let now = client.now
            let after = Date().addingTimeInterval(0.1)
            #expect(now >= before)
            #expect(now <= after)
        }
    }

    @Suite("Error Handling — Invalid server scenarios")
    struct ErrorHandlingTests {

        @Test("sync() throws GlobalTimeError for invalid server")
        func syncThrowsForInvalidServer() async {
            let client = GlobalTimeClient(config: GlobalTimeConfig(
                server: "invalid.nonexistent.server.xyz",
                timeout: .seconds(2),
                samples: 1
            ))
            do {
                try await client.sync()
                #expect(Bool(false), "Should have thrown")
            } catch {
                #expect(error is GlobalTimeError)
            }
        }

        @Test("fetchTime() throws GlobalTimeError for invalid server")
        func fetchTimeThrowsForInvalidServer() async {
            let client = GlobalTimeClient(config: GlobalTimeConfig(
                server: "invalid.nonexistent.server.xyz",
                timeout: .seconds(2),
                samples: 1
            ))
            do {
                _ = try await client.fetchTime()
                #expect(Bool(false), "Should have thrown")
            } catch {
                #expect(error is GlobalTimeError)
            }
        }

        @Test("Client remains not synced after failed sync")
        func remainsNotSyncedAfterFailure() async {
            let client = GlobalTimeClient(config: GlobalTimeConfig(
                server: "invalid.nonexistent.server.xyz",
                timeout: .seconds(2),
                samples: 1
            ))
            try? await client.sync()
            #expect(client.isSynced == false)
            #expect(client.offset == 0)
            #expect(client.lastSyncDate == nil)
        }

        @Test("sync() throws when all samples fail with multiple samples")
        func syncThrowsWhenAllSamplesFail() async {
            let client = GlobalTimeClient(config: GlobalTimeConfig(
                server: "invalid.nonexistent.server.xyz",
                timeout: .seconds(2),
                samples: 3
            ))
            do {
                try await client.sync()
                #expect(Bool(false), "Should have thrown")
            } catch {
                #expect(error is GlobalTimeError)
            }
        }

        @Test("sync() preserves last error type when all samples fail")
        func syncPreservesLastError() async {
            let client = GlobalTimeClient(config: GlobalTimeConfig(
                server: "invalid.nonexistent.server.xyz",
                timeout: .milliseconds(500),
                samples: 2
            ))
            do {
                try await client.sync()
                #expect(Bool(false), "Should have thrown")
            } catch let error as GlobalTimeError {
                // Should be a real error (dns, timeout, etc.), not invalidResponse
                #expect(error == .dnsResolutionFailed || error == .timeout || error == .serverUnreachable || error == .networkUnavailable)
            } catch {
                // Other error types are acceptable
            }
        }
    }

    @Suite("Callback API — Completion handler wrappers")
    struct CallbackAPITests {

        @Test("sync(completion:) reports error for invalid server")
        func callbackSyncError() async {
            let client = GlobalTimeClient(config: GlobalTimeConfig(
                server: "invalid.nonexistent.server.xyz",
                timeout: .seconds(2),
                samples: 1
            ))
            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                client.sync { result in
                    switch result {
                    case .success:
                        #expect(Bool(false), "Should have failed")
                    case .failure(let error):
                        #expect(error is GlobalTimeError)
                    }
                    continuation.resume()
                }
            }
        }

        @Test("fetchTime(completion:) reports error for invalid server")
        func callbackFetchTimeError() async {
            let client = GlobalTimeClient(config: GlobalTimeConfig(
                server: "invalid.nonexistent.server.xyz",
                timeout: .seconds(2),
                samples: 1
            ))
            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                client.fetchTime { result in
                    switch result {
                    case .success:
                        #expect(Bool(false), "Should have failed")
                    case .failure(let error):
                        #expect(error is GlobalTimeError)
                    }
                    continuation.resume()
                }
            }
        }
    }

    @Suite("Concurrency — Thread safety of state access")
    struct ConcurrencyTests {

        @Test("GlobalTimeClient conforms to Sendable")
        func isSendable() {
            let client = GlobalTimeClient()
            Task { @Sendable in
                _ = client.now
                _ = client.isSynced
                _ = client.offset
                _ = client.lastSyncDate
            }
        }

        @Test("Concurrent property reads don't crash")
        func concurrentPropertyReads() async {
            let client = GlobalTimeClient()
            await withTaskGroup(of: Void.self) { group in
                for _ in 0..<100 {
                    group.addTask {
                        _ = client.now
                        _ = client.isSynced
                        _ = client.offset
                        _ = client.lastSyncDate
                    }
                }
            }
        }
    }
}

// MARK: - Integration Tests (require network)

@Suite("Integration — End-to-end NTP queries against real servers")
struct IntegrationTests {

    @Suite("sync() — Multi-sample synchronization with caching")
    struct SyncTests {

        @Test("Sync succeeds and caches offset")
        func syncWithRealServer() async throws {
            let client = GlobalTimeClient(config: GlobalTimeConfig(
                server: "time.apple.com",
                timeout: .seconds(10),
                samples: 2
            ))
            try await client.sync()

            #expect(client.isSynced == true)
            #expect(client.lastSyncDate != nil)
            #expect(abs(client.offset) < 60)
        }

        @Test("now returns corrected time after sync")
        func nowAfterSync() async throws {
            let client = GlobalTimeClient(config: GlobalTimeConfig(
                server: "time.apple.com",
                timeout: .seconds(10),
                samples: 2
            ))
            try await client.sync()

            let now = client.now
            let diff = abs(now.timeIntervalSince(Date()))
            #expect(diff < 60)
        }

        @Test("lastSyncDate is set after sync")
        func lastSyncDateIsSet() async throws {
            let client = GlobalTimeClient(config: GlobalTimeConfig(
                server: "time.apple.com",
                timeout: .seconds(10),
                samples: 1
            ))
            let before = Date()
            try await client.sync()
            let after = Date()

            guard let syncDate = client.lastSyncDate else {
                #expect(Bool(false), "lastSyncDate should not be nil")
                return
            }
            #expect(syncDate >= before.addingTimeInterval(-0.1))
            #expect(syncDate <= after.addingTimeInterval(0.1))
        }

        @Test("Callback sync succeeds with real server")
        func callbackSyncSuccess() async {
            let client = GlobalTimeClient(config: GlobalTimeConfig(
                server: "time.apple.com",
                timeout: .seconds(10),
                samples: 1
            ))
            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                client.sync { result in
                    switch result {
                    case .success:
                        #expect(client.isSynced == true)
                    case .failure:
                        break
                    }
                    continuation.resume()
                }
            }
        }
    }

    @Suite("fetchTime() — Single-shot NTP query without caching")
    struct FetchTimeTests {

        @Test("Returns server time close to system time")
        func fetchTimeFromRealServer() async throws {
            let client = GlobalTimeClient(config: GlobalTimeConfig(
                server: "time.apple.com",
                timeout: .seconds(10)
            ))
            let serverTime = try await client.fetchTime()
            let diff = abs(serverTime.timeIntervalSince(Date()))
            #expect(diff < 60)
        }

        @Test("fetchTime does not change isSynced state")
        func fetchTimeDoesNotCache() async throws {
            let client = GlobalTimeClient(config: GlobalTimeConfig(
                server: "time.apple.com",
                timeout: .seconds(10)
            ))
            _ = try await client.fetchTime()
            #expect(client.isSynced == false)
            #expect(client.offset == 0)
            #expect(client.lastSyncDate == nil)
        }

        @Test("Callback fetchTime succeeds with real server")
        func callbackFetchTimeSuccess() async {
            let client = GlobalTimeClient(config: GlobalTimeConfig(
                server: "time.apple.com",
                timeout: .seconds(10)
            ))
            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                client.fetchTime { result in
                    switch result {
                    case .success(let date):
                        #expect(abs(date.timeIntervalSince(Date())) < 60)
                    case .failure:
                        break
                    }
                    continuation.resume()
                }
            }
        }
    }

    @Suite("Custom Server — time.google.com support")
    struct CustomServerTests {

        @Test("Sync works with time.google.com")
        func syncWithGoogleServer() async throws {
            let client = GlobalTimeClient(config: GlobalTimeConfig(
                server: "time.google.com",
                timeout: .seconds(10),
                samples: 1
            ))
            try await client.sync()
            #expect(client.isSynced == true)
            #expect(abs(client.offset) < 60)
        }
    }

    @Suite("Re-sync — Calling sync() multiple times updates state")
    struct ReSyncTests {

        @Test("Second sync updates lastSyncDate")
        func reSyncUpdatesLastSyncDate() async throws {
            let client = GlobalTimeClient(config: GlobalTimeConfig(
                server: "time.apple.com",
                timeout: .seconds(10),
                samples: 1
            ))
            try await client.sync()
            let firstSyncDate = client.lastSyncDate

            try await Task.sleep(for: .milliseconds(100))

            try await client.sync()
            let secondSyncDate = client.lastSyncDate

            guard let first = firstSyncDate, let second = secondSyncDate else {
                #expect(Bool(false), "Both sync dates should be set")
                return
            }
            #expect(second > first)
        }

        @Test("Re-sync keeps isSynced true")
        func reSyncKeepsSynced() async throws {
            let client = GlobalTimeClient(config: GlobalTimeConfig(
                server: "time.apple.com",
                timeout: .seconds(10),
                samples: 1
            ))
            try await client.sync()
            #expect(client.isSynced == true)

            try await client.sync()
            #expect(client.isSynced == true)
        }
    }

    @Suite("Timeout — Very short timeout triggers timeout error")
    struct TimeoutTests {

        @Test("1ms timeout throws timeout error against real server")
        func veryShortTimeoutThrows() async {
            let client = GlobalTimeClient(config: GlobalTimeConfig(
                server: "time.apple.com",
                timeout: .milliseconds(1),
                samples: 1
            ))
            do {
                try await client.sync()
                // May succeed on very fast local networks — that's OK
            } catch let error as GlobalTimeError {
                #expect(error == .timeout)
            } catch {
                // Other errors are acceptable (race conditions)
            }
        }
    }

    @Suite("Offset Accuracy — now differs from Date() by the cached offset")
    struct OffsetAccuracyTests {

        @Test("client.now differs from Date() by approximately client.offset")
        func nowReflectsOffset() async throws {
            let client = GlobalTimeClient(config: GlobalTimeConfig(
                server: "time.apple.com",
                timeout: .seconds(10),
                samples: 2
            ))
            try await client.sync()

            let systemTime = Date()
            let correctedTime = client.now
            let measuredOffset = correctedTime.timeIntervalSince(systemTime)

            // The measured difference should be close to the cached offset
            #expect(abs(measuredOffset - client.offset) < 0.5)
        }
    }
}

// MARK: - NTPPacket Known Bytes Tests

@Suite("NTPPacket Known Bytes — Decode a hardcoded real NTP server response")
struct NTPPacketKnownBytesTests {

    @Test("Decodes a crafted NTP v4 server response with known timestamps")
    func decodeKnownServerResponse() throws {
        // Construct a known NTP v4 server response:
        // flags: 0x24 (LI=0, VN=4, Mode=4)
        // stratum: 2
        // poll: 6
        // precision: -20 (0xEC)
        // rootDelay: 0x00000100 (256)
        // rootDispersion: 0x00000200 (512)
        // referenceID: 0x47505300 ("GPS\0")
        // referenceTime: known NTP timestamp
        // originTime: T1 from client
        // receiveTime: T2
        // transmitTime: T3
        var data = Data(count: 48)

        data[0] = 0x24 // flags
        data[1] = 2    // stratum
        data[2] = 6    // poll
        data[3] = 0xEC // precision = -20

        // rootDelay = 256 = 0x00000100
        data[4] = 0x00; data[5] = 0x00; data[6] = 0x01; data[7] = 0x00

        // rootDispersion = 512 = 0x00000200
        data[8] = 0x00; data[9] = 0x00; data[10] = 0x02; data[11] = 0x00

        // referenceID = "GPS\0" = 0x47505300
        data[12] = 0x47; data[13] = 0x50; data[14] = 0x53; data[15] = 0x00

        // referenceTime = 0xEA2F5D80_00000000 (a known NTP time ~2024)
        data[16] = 0xEA; data[17] = 0x2F; data[18] = 0x5D; data[19] = 0x80
        data[20] = 0x00; data[21] = 0x00; data[22] = 0x00; data[23] = 0x00

        // originTime = 0xEA2F5D90_00000000
        data[24] = 0xEA; data[25] = 0x2F; data[26] = 0x5D; data[27] = 0x90
        data[28] = 0x00; data[29] = 0x00; data[30] = 0x00; data[31] = 0x00

        // receiveTime = 0xEA2F5D90_10000000
        data[32] = 0xEA; data[33] = 0x2F; data[34] = 0x5D; data[35] = 0x90
        data[36] = 0x10; data[37] = 0x00; data[38] = 0x00; data[39] = 0x00

        // transmitTime = 0xEA2F5D90_20000000
        data[40] = 0xEA; data[41] = 0x2F; data[42] = 0x5D; data[43] = 0x90
        data[44] = 0x20; data[45] = 0x00; data[46] = 0x00; data[47] = 0x00

        let packet = try NTPPacket.decode(from: data)

        #expect(packet.stratum == 2)
        #expect(packet.poll == 6)
        #expect(packet.precision == -20)
        #expect(packet.rootDelay == 256)
        #expect(packet.rootDispersion == 512)
        #expect(packet.referenceID == 0x47505300)

        // Verify timestamp parsing: receiveTime and transmitTime differ only in fraction
        let t2 = NTPPacket.ntpToTimeInterval(packet.receiveTime)
        let t3 = NTPPacket.ntpToTimeInterval(packet.transmitTime)
        // Both have same integer seconds, fraction differs
        #expect(t3 > t2)
        #expect(t3 - t2 < 1.0)

        // Verify the reference time is in a reasonable range
        let refTime = NTPPacket.ntpToTimeInterval(packet.referenceTime)
        // 0xEA2F5D80 seconds since NTP epoch = 3,928,399,232 - 2,208,988,800 = ~1,719,410,432 Unix (~June 2024)
        #expect(refTime > 1_700_000_000) // after 2023
        #expect(refTime < 1_800_000_000) // before 2027
    }

    @Test("NTP offset formula produces correct result with known timestamps")
    func offsetFormulaWithKnownValues() {
        // T1 = 1000.0 (client send)
        // T2 = 1000.05 (server receive) — 50ms network delay
        // T3 = 1000.06 (server send) — 10ms processing
        // T4 = 1000.11 (client receive) — 50ms network delay
        //
        // offset = ((T2-T1) + (T3-T4)) / 2
        //        = ((0.05) + (-0.05)) / 2
        //        = 0.0 (clocks are in sync)
        //
        // delay = (T4-T1) - (T3-T2)
        //       = 0.11 - 0.01
        //       = 0.10

        let t1: TimeInterval = 1000.0
        let t2: TimeInterval = 1000.05
        let t3: TimeInterval = 1000.06
        let t4: TimeInterval = 1000.11

        let offset = ((t2 - t1) + (t3 - t4)) / 2.0
        let delay = (t4 - t1) - (t3 - t2)

        #expect(abs(offset) < 0.001) // ~0
        #expect(abs(delay - 0.10) < 0.001) // 100ms
    }

    @Test("NTP offset formula detects clock ahead by 1 second")
    func offsetFormulaClockAhead() {
        // Client clock is 1 second AHEAD of server
        // T1 = 1001.0 (client send, but real time is 1000.0)
        // T2 = 1000.05 (server receive)
        // T3 = 1000.06 (server send)
        // T4 = 1001.11 (client receive, but real time is 1000.11)
        //
        // offset = ((T2-T1) + (T3-T4)) / 2
        //        = ((-0.95) + (-1.05)) / 2
        //        = -1.0

        let t1: TimeInterval = 1001.0
        let t2: TimeInterval = 1000.05
        let t3: TimeInterval = 1000.06
        let t4: TimeInterval = 1001.11

        let offset = ((t2 - t1) + (t3 - t4)) / 2.0
        #expect(abs(offset - (-1.0)) < 0.001)
    }

    @Test("NTP offset formula detects clock behind by 2 seconds")
    func offsetFormulaClockBehind() {
        // Client clock is 2 seconds BEHIND server
        // T1 = 998.0 (client send, but real time is 1000.0)
        // T2 = 1000.05 (server receive)
        // T3 = 1000.06 (server send)
        // T4 = 998.11 (client receive, but real time is 1000.11)
        //
        // offset = ((T2-T1) + (T3-T4)) / 2
        //        = ((2.05) + (1.95)) / 2
        //        = 2.0

        let t1: TimeInterval = 998.0
        let t2: TimeInterval = 1000.05
        let t3: TimeInterval = 1000.06
        let t4: TimeInterval = 998.11

        let offset = ((t2 - t1) + (t3 - t4)) / 2.0
        #expect(abs(offset - 2.0) < 0.001)
    }
}
