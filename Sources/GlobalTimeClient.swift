//
//  GlobalTimeClient.swift
//  GlobalTimeKit
//
//  Created by Dmitry Yurkovski on 11/03/2026.
//

import Foundation
import os

/// The main entry point for obtaining accurate server time via NTP.
///
/// `GlobalTimeClient` synchronizes with an NTP server, caches the clock offset,
/// and provides instant access to corrected time without additional network calls.
///
/// ## Quick Start
///
/// ```swift
/// import GlobalTimeKit
///
/// let client = GlobalTimeClient()
/// try await client.sync()
///
/// // Instant access — no await needed
/// let now = client.now
/// ```
///
/// ## Custom Server
///
/// ```swift
/// let client = GlobalTimeClient(config: GlobalTimeConfig(
///     server: "time.google.com",
///     timeout: .seconds(10),
///     samples: 6
/// ))
/// try await client.sync()
/// ```
///
/// ## One-Shot Query
///
/// ```swift
/// let serverTime = try await GlobalTimeClient().fetchTime()
/// ```
///
/// ## Thread Safety
///
/// `GlobalTimeClient` is fully `Sendable` and safe to use from any thread or actor.
/// Internal state is protected by `OSAllocatedUnfairLock`.
public final class GlobalTimeClient: Sendable {

    /// The current version of the GlobalTimeKit library.
    public static let version = "1.0.1"

    /// The configuration used by this client.
    public let config: GlobalTimeConfig

    private let ntpClient: NTPClient
    private let state: OSAllocatedUnfairLock<State>
    private let logger: GTKLogger

    private struct State {
        var freeze: TimeFreeze?
        var lastSyncDate: Date?
    }

    /// Creates a new client with the given configuration.
    ///
    /// - Parameter config: NTP configuration. Uses default values
    ///   (`time.apple.com`, 5s timeout, 4 samples) when omitted.
    public init(config: GlobalTimeConfig = .init()) {
        self.config = config
        self.ntpClient = NTPClient()
        self.state = OSAllocatedUnfairLock(initialState: State())
        self.logger = GTKLogger(level: config.logLevel)
    }

    // MARK: - Async API

    /// Synchronizes with the NTP server by collecting multiple samples
    /// and caching the most accurate offset.
    ///
    /// After a successful sync, ``now``, ``isSynced``, ``offset``,
    /// and ``lastSyncDate`` reflect the updated state.
    ///
    /// The method collects ``GlobalTimeConfig/samples`` NTP responses
    /// and picks the one with the lowest round-trip delay for best accuracy.
    ///
    /// - Throws: ``GlobalTimeError`` if all samples fail.
    ///
    /// ```swift
    /// let client = GlobalTimeClient()
    /// try await client.sync()
    /// print("Offset: \(client.offset)s")
    /// ```
    public func sync() async throws {
        logger.log(.info, "Starting sync with \(config.server), \(config.samples) samples")
        var best: NTPResponse?
        var lastError: Error?
        for i in 0..<config.samples {
            do {
                let response = try await ntpClient.query(
                    server: config.server,
                    timeout: config.timeout
                )
                logger.log(.debug, "Sample \(i + 1)/\(config.samples): offset=\(String(format: "%.4f", response.offset))s, delay=\(String(format: "%.4f", response.roundTripDelay))s")
                if let current = best {
                    if response.roundTripDelay < current.roundTripDelay {
                        best = response
                    }
                } else {
                    best = response
                }
            } catch {
                logger.log(.warning, "Sample \(i + 1)/\(config.samples) failed: \(error.localizedDescription)")
                lastError = error
            }
        }
        guard let response = best else {
            logger.log(.error, "Sync failed — all \(config.samples) samples failed")
            throw lastError ?? GlobalTimeError.invalidResponse
        }

        let freeze = TimeFreeze(
            offset: response.offset,
            uptime: MonotonicClock.uptime(),
            timestamp: Date()
        )
        state.withLock {
            $0.freeze = freeze
            $0.lastSyncDate = Date()
        }
        logger.log(.info, "Sync complete: offset=\(String(format: "%.4f", response.offset))s, delay=\(String(format: "%.4f", response.roundTripDelay))s, stratum=\(response.stratum)")
    }

    /// Performs a single NTP query and returns the server time directly.
    ///
    /// Unlike ``sync()``, this does **not** cache the offset.
    /// Useful for one-off time checks.
    ///
    /// - Returns: The current server time as a `Date`.
    /// - Throws: ``GlobalTimeError`` if the query fails.
    ///
    /// ```swift
    /// let serverTime = try await GlobalTimeClient().fetchTime()
    /// ```
    public func fetchTime() async throws -> Date {
        logger.log(.info, "Fetching time from \(config.server)")
        let response = try await ntpClient.query(
            server: config.server,
            timeout: config.timeout
        )
        logger.log(.info, "Fetched time: offset=\(String(format: "%.4f", response.offset))s")
        return response.serverTime
    }

    // MARK: - Synchronous Access

    /// The corrected current date using the cached NTP offset.
    ///
    /// If ``sync()`` has not been called yet, falls back to `Date()`
    /// (the device's system clock).
    ///
    /// This property is non-blocking and does not perform any network I/O.
    ///
    /// ```swift
    /// let timestamp = client.now.timeIntervalSince1970
    /// ```
    public var now: Date {
        state.withLock { s in
            s.freeze?.now ?? Date()
        }
    }

    /// The corrected current time as a Unix timestamp (seconds since 1970-01-01 UTC).
    ///
    /// Useful for API requests, JWT tokens, and other systems requiring Unix time.
    ///
    /// ```swift
    /// let timestamp = client.unixTimestamp
    /// // Example: 1710598800.0
    /// ```
    public var unixTimestamp: TimeInterval {
        now.timeIntervalSince1970
    }

    /// The corrected current time in ISO 8601 format with GMT timezone.
    ///
    /// Returns time in the format: `yyyy-MM-dd'T'HH:mm:ss'Z'`
    ///
    /// ```swift
    /// let iso = client.iso8601GMT
    /// // Example: "2026-03-16T14:30:00Z"
    /// ```
    public var iso8601GMT: String {
        formattedGMT("yyyy-MM-dd'T'HH:mm:ss'Z'")
    }

    /// Formats the corrected current time in GMT timezone with a custom format.
    ///
    /// Uses the Gregorian calendar with `en_US_POSIX` locale for consistent,
    /// locale-independent formatting.
    ///
    /// - Parameter format: Date format string (e.g., `"yyyy-MM-dd HH:mm:ss"`).
    ///   Defaults to ISO 8601 format.
    /// - Returns: Formatted time string in GMT timezone.
    ///
    /// ```swift
    /// let custom = client.formattedGMT("dd/MM/yyyy HH:mm")
    /// // Example: "16/03/2026 14:30"
    /// ```
    public func formattedGMT(_ format: String = "yyyy-MM-dd'T'HH:mm:ss'Z'") -> String {
        let formatter = DateFormatter()
        formatter.timeZone = TimeZone(identifier: "GMT")
        formatter.dateFormat = format
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        return formatter.string(from: now)
    }

    /// Whether the client has successfully synced at least once.
    public var isSynced: Bool {
        state.withLock { $0.freeze != nil }
    }

    /// The cached NTP offset in seconds.
    ///
    /// Positive means the local clock is behind the server.
    /// Returns `0` if not yet synced.
    public var offset: TimeInterval {
        state.withLock { $0.freeze?.offset ?? 0 }
    }

    /// The date of the last successful synchronization, or `nil` if never synced.
    public var lastSyncDate: Date? {
        state.withLock { $0.lastSyncDate }
    }

    // MARK: - Callback API

    /// Synchronizes with the NTP server using a completion handler.
    ///
    /// This is a convenience wrapper for projects that don't use `async/await`.
    ///
    /// - Parameter completion: Called with `.success(())` on success
    ///   or `.failure(error)` on failure.
    ///
    /// ```swift
    /// client.sync { result in
    ///     switch result {
    ///     case .success:
    ///         print("Synced! Offset: \(client.offset)")
    ///     case .failure(let error):
    ///         print("Error: \(error)")
    ///     }
    /// }
    /// ```
    public func sync(completion: @escaping @Sendable (Result<Void, Error>) -> Void) {
        Task {
            do {
                try await self.sync()
                completion(.success(()))
            } catch {
                completion(.failure(error))
            }
        }
    }

    /// Fetches the server time using a completion handler.
    ///
    /// This is a convenience wrapper for projects that don't use `async/await`.
    ///
    /// - Parameter completion: Called with `.success(date)` on success
    ///   or `.failure(error)` on failure.
    ///
    /// ```swift
    /// client.fetchTime { result in
    ///     switch result {
    ///     case .success(let date):
    ///         print("Server time: \(date)")
    ///     case .failure(let error):
    ///         print("Error: \(error)")
    ///     }
    /// }
    /// ```
    public func fetchTime(completion: @escaping @Sendable (Result<Date, Error>) -> Void) {
        Task {
            do {
                let date = try await self.fetchTime()
                completion(.success(date))
            } catch {
                completion(.failure(error))
            }
        }
    }
}
