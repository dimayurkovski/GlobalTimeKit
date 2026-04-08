//
//  GlobalTimeAutoClient.swift
//  GlobalTimeKit
//

import Foundation
import Network
import os

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#elseif canImport(WatchKit)
import WatchKit
#endif

/// A smart NTP client that automatically re-syncs when network connectivity
/// is restored or the app returns to the foreground.
///
/// `GlobalTimeAutoClient` wraps ``GlobalTimeClient`` and adds:
/// - **Reachability monitoring** — re-syncs when network comes back online
/// - **Foreground monitoring** — re-syncs when the app becomes active
/// - **Automatic retry** — retries failed syncs with exponential backoff
///
/// Like ``GlobalTimeClient``, the first sync must be triggered explicitly.
/// After that, the client maintains itself automatically.
///
/// ## Quick Start
///
/// ```swift
/// let client = GlobalTimeAutoClient()
/// try await client.sync()
///
/// // From now on, client re-syncs automatically
/// let now = client.now
/// ```
///
/// ## Custom Configuration
///
/// ```swift
/// let client = GlobalTimeAutoClient(
///     config: GlobalTimeConfig(server: "time.google.com"),
///     maxRetries: 5,
///     retryBaseDelay: .seconds(2)
/// )
/// try await client.sync()
/// ```
public final class GlobalTimeAutoClient: GlobalTimeClientProtocol {

    // MARK: - Private State

    private let inner: GlobalTimeClient
    private let maxRetries: Int
    private let retryBaseDelay: Duration
    private let logger: GTKLogger

    private let monitor: NWPathMonitor
    private let monitorQueue: DispatchQueue

    private let syncLock: OSAllocatedUnfairLock<SyncState>

    private struct SyncState {
        var isSyncedOnce: Bool = false
        var retryTask: Task<Void, Never>?
        var isStopped: Bool = false
    }

    // MARK: - Init

    /// Creates a new auto-syncing client.
    ///
    /// - Parameters:
    ///   - config: NTP configuration. Uses defaults when omitted.
    ///   - maxRetries: Maximum number of retry attempts after a failed sync. Default: `3`.
    ///   - retryBaseDelay: Initial delay before the first retry. Doubles with each attempt. Default: `.seconds(2)`.
    public init(
        config: GlobalTimeConfig = .init(),
        maxRetries: Int = 3,
        retryBaseDelay: Duration = .seconds(2)
    ) {
        self.inner = GlobalTimeClient(config: config)
        self.maxRetries = maxRetries
        self.retryBaseDelay = retryBaseDelay
        self.logger = GTKLogger(level: config.logLevel)
        self.monitor = NWPathMonitor()
        self.monitorQueue = DispatchQueue(label: "com.globaltimekit.automonitor", qos: .utility)
        self.syncLock = OSAllocatedUnfairLock(initialState: SyncState())

        setupMonitors()
    }

    deinit {
        stop()
    }

    /// Stops all automatic monitoring: network reachability, foreground detection, and pending retries.
    /// After calling `stop()`, the client will no longer re-sync automatically.
    public func stop() {
        syncLock.withLock { state in
            state.isStopped = true
            state.retryTask?.cancel()
            state.retryTask = nil
        }
        monitor.cancel()
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - GlobalTimeClientProtocol

    /// Synchronizes with the NTP server and caches the offset.
    /// After the first successful sync, the client re-syncs automatically.
    public func sync() async throws {
        try await inner.sync()
        syncLock.withLock { $0.isSyncedOnce = true }
    }

    /// Performs a single NTP query and returns the server time without caching.
    public func fetchTime() async throws -> Date {
        try await inner.fetchTime()
    }

    public var now: Date { inner.now }
    public var unixTimestamp: TimeInterval { inner.unixTimestamp }
    public var iso8601GMT: String { inner.iso8601GMT }
    public func formattedGMT(_ format: String) -> String { inner.formattedGMT(format) }
    public var isSynced: Bool { inner.isSynced }
    public var offset: TimeInterval { inner.offset }
    public var lastSyncDate: Date? { inner.lastSyncDate }

    // MARK: - Private

    private func setupMonitors() {
        setupNetworkMonitor()
        setupForegroundMonitor()
    }

    private func setupNetworkMonitor() {
        monitor.pathUpdateHandler = { [weak self] path in
            guard let self else { return }
            guard path.status == .satisfied else { return }
            guard self.syncLock.withLock({ $0.isSyncedOnce && !$0.isStopped }) else { return }
            self.logger.log(.info, "Network restored — scheduling re-sync")
            self.scheduleResync()
        }
        monitor.start(queue: monitorQueue)
    }

    private func setupForegroundMonitor() {
#if canImport(UIKit)
        NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: nil
        ) { [weak self] _ in
            self?.handleForeground()
        }
#elseif canImport(AppKit)
        NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: nil
        ) { [weak self] _ in
            self?.handleForeground()
        }
#elseif canImport(WatchKit)
        NotificationCenter.default.addObserver(
            forName: WKExtension.applicationDidBecomeActiveNotification,
            object: nil,
            queue: nil
        ) { [weak self] _ in
            self?.handleForeground()
        }
#endif
    }

    private func handleForeground() {
        guard syncLock.withLock({ $0.isSyncedOnce && !$0.isStopped }) else { return }
        logger.log(.info, "App became active — scheduling re-sync")
        scheduleResync()
    }

    private func scheduleResync() {
        syncLock.withLock { state in
            state.retryTask?.cancel()
            state.retryTask = Task { [weak self] in
                await self?.resyncWithRetry()
            }
        }
    }

    private func resyncWithRetry() async {
        var delay = retryBaseDelay
        for attempt in 1...max(1, maxRetries + 1) {
            guard !Task.isCancelled else { return }
            do {
                try await inner.sync()
                logger.log(.info, "Auto re-sync succeeded")
                return
            } catch {
                if attempt > maxRetries {
                    logger.log(.error, "Auto re-sync failed after \(maxRetries) retries: \(error.localizedDescription)")
                    return
                }
                logger.log(.warning, "Auto re-sync attempt \(attempt) failed, retrying in \(delay)s")
                try? await Task.sleep(for: delay)
                delay = delay * 2
            }
        }
    }
}
