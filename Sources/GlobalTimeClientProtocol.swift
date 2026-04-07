//
//  GlobalTimeClientProtocol.swift
//  GlobalTimeKit
//

import Foundation

/// A common interface for GlobalTimeKit clients.
///
/// Both ``GlobalTimeClient`` and ``GlobalTimeAutoClient`` conform to this protocol,
/// allowing them to be used interchangeably.
public protocol GlobalTimeClientProtocol: Sendable {

    // MARK: - Async API

    /// Synchronizes with the NTP server and caches the offset.
    func sync() async throws

    /// Performs a single NTP query and returns the server time without caching.
    func fetchTime() async throws -> Date

    // MARK: - Synchronous Access

    /// The corrected current date using the cached NTP offset.
    /// Falls back to `Date()` if not yet synced.
    var now: Date { get }

    /// Unix timestamp in GMT (seconds since 1970-01-01 UTC).
    var unixTimestamp: TimeInterval { get }

    /// ISO 8601 formatted time in GMT timezone (e.g. `"2026-03-16T14:30:00Z"`).
    var iso8601GMT: String { get }

    /// Formats the corrected current time in GMT with a custom format string.
    func formattedGMT(_ format: String) -> String

    /// Whether the client has successfully synced at least once.
    var isSynced: Bool { get }

    /// The cached NTP offset in seconds. Returns `0` if not yet synced.
    var offset: TimeInterval { get }

    /// The date of the last successful sync, or `nil` if never synced.
    var lastSyncDate: Date? { get }
}

// MARK: - Default Callback API

public extension GlobalTimeClientProtocol {

    /// Synchronizes with the NTP server using a completion handler.
    func sync(completion: @escaping @Sendable (Result<Void, Error>) -> Void) {
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
    func fetchTime(completion: @escaping @Sendable (Result<Date, Error>) -> Void) {
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
