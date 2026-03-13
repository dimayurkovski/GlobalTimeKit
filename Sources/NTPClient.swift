//
//  NTPClient.swift
//  GlobalTimeKit
//
//  Created by Dmitry Yurkovski on 11/03/2026.
//

import Foundation
import Network

/// Low-level NTP client that sends a single UDP query to an NTP server
/// and returns the parsed response with offset and delay.
///
/// Uses `NWConnection` from `Network.framework` for native UDP support
/// without any third-party dependencies.
internal final class NTPClient: Sendable {

    /// NTP server port.
    private static let ntpPort: UInt16 = 123

    /// Sends a single NTP query to the specified server and returns the response.
    ///
    /// - Parameters:
    ///   - server: NTP server hostname (e.g. `"time.apple.com"`).
    ///   - port: UDP port number. Default: `123`.
    ///   - timeout: Maximum time to wait for a response.
    /// - Returns: An ``NTPResponse`` containing offset, delay, server time, and stratum.
    /// - Throws: ``GlobalTimeError`` on timeout, invalid response, DNS failure, or network issues.
    func query(
        server: String,
        port: UInt16 = ntpPort,
        timeout: Duration
    ) async throws -> NTPResponse {
        let host = NWEndpoint.Host(server)
        guard let ntpPort = NWEndpoint.Port(rawValue: port) else {
            throw GlobalTimeError.serverUnreachable
        }
        let connection = NWConnection(host: host, port: ntpPort, using: .udp)

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<NTPResponse, Error>) in
                let resumed = Resumed()

                connection.stateUpdateHandler = { state in
                    switch state {
                    case .ready:
                        self.sendRequest(on: connection, resumed: resumed, continuation: continuation)
                    case .failed(let error):
                        guard resumed.tryResume() else { return }
                        connection.cancel()
                        continuation.resume(throwing: self.mapError(error))
                    case .waiting(let error):
                        guard resumed.tryResume() else { return }
                        connection.cancel()
                        continuation.resume(throwing: self.mapError(error))
                    default:
                        break
                    }
                }

                connection.start(queue: .global(qos: .utility))

                // Schedule timeout
                let timeoutNanoseconds = Int(timeout.components.seconds) * 1_000_000_000
                    + Int(timeout.components.attoseconds / 1_000_000_000)
                DispatchQueue.global().asyncAfter(deadline: .now() + .nanoseconds(timeoutNanoseconds)) {
                    guard resumed.tryResume() else { return }
                    connection.cancel()
                    continuation.resume(throwing: GlobalTimeError.timeout)
                }
            }
        } onCancel: {
            connection.cancel()
        }
    }

    // MARK: - Private

    /// Sends the NTP request packet and waits for the response.
    private func sendRequest(
        on connection: NWConnection,
        resumed: Resumed,
        continuation: CheckedContinuation<NTPResponse, Error>
    ) {
        let t1 = Date().timeIntervalSince1970
        let packet = NTPPacket.makeClientPacket(transmitTime: t1)
        let data = packet.encode()

        connection.send(content: data, completion: .contentProcessed { error in
            if let error {
                guard resumed.tryResume() else { return }
                connection.cancel()
                continuation.resume(throwing: self.mapError(error))
                return
            }

            connection.receiveMessage { content, _, _, error in
                let t4 = Date().timeIntervalSince1970

                guard resumed.tryResume() else { return }
                connection.cancel()

                if let error {
                    continuation.resume(throwing: self.mapError(error))
                    return
                }

                guard let content else {
                    continuation.resume(throwing: GlobalTimeError.invalidResponse)
                    return
                }

                do {
                    let response = try self.parseResponse(data: content, t1: t1, t4: t4)
                    continuation.resume(returning: response)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        })
    }

    /// Parses the raw NTP response data and computes offset and delay.
    private func parseResponse(data: Data, t1: TimeInterval, t4: TimeInterval) throws -> NTPResponse {
        let packet = try NTPPacket.decode(from: data)

        let t2 = NTPPacket.ntpToTimeInterval(packet.receiveTime)
        let t3 = NTPPacket.ntpToTimeInterval(packet.transmitTime)

        // Standard NTP offset and delay formulas
        let offset = ((t2 - t1) + (t3 - t4)) / 2.0
        let delay = (t4 - t1) - (t3 - t2)

        return NTPResponse(
            offset: offset,
            roundTripDelay: delay,
            serverTime: Date().addingTimeInterval(offset),
            stratum: packet.stratum
        )
    }

    /// Maps `NWError` to ``GlobalTimeError``.
    private func mapError(_ error: NWError) -> GlobalTimeError {
        switch error {
        case .dns(_):
            return .dnsResolutionFailed
        case .posix(let code) where code == .ENETUNREACH || code == .ENETDOWN:
            return .networkUnavailable
        case .posix(let code) where code == .ECONNREFUSED || code == .ECONNRESET || code == .EHOSTUNREACH:
            return .serverUnreachable
        default:
            return .serverUnreachable
        }
    }
}

// MARK: - Resumed (thread-safe one-shot flag)

/// A thread-safe flag ensuring that a continuation is resumed exactly once.
private final class Resumed: @unchecked Sendable {
    private var _resumed = false
    private let lock = NSLock()

    /// Attempts to claim the resume. Returns `true` on the first call,
    /// `false` on all subsequent calls.
    func tryResume() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        if _resumed { return false }
        _resumed = true
        return true
    }
}
