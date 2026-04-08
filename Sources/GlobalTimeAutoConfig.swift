//
//  GlobalTimeAutoConfig.swift
//  GlobalTimeKit
//

import Foundation

/// Configuration for ``GlobalTimeAutoClient``.
///
/// Combines NTP connection settings with automatic re-sync behaviour.
///
/// ```swift
/// // Default configuration
/// let config = GlobalTimeAutoConfig()
///
/// // Custom configuration
/// let config = GlobalTimeAutoConfig(
///     server: "time.google.com",
///     maxRetries: 5,
///     alwaysReactToEvents: true
/// )
/// ```
public struct GlobalTimeAutoConfig: Sendable {

    // MARK: - NTP Settings

    /// NTP server hostname. Default: `"time.apple.com"`.
    public let server: String

    /// Timeout for a single NTP request. Default: `.seconds(5)`.
    public let timeout: Duration

    /// Number of NTP samples to collect during sync.
    /// The sample with the lowest round-trip delay is selected for maximum accuracy.
    /// Default: `4`.
    public let samples: Int

    /// Diagnostic log verbosity. Default: `.info`.
    public let logLevel: GlobalTimeConfig.LogLevel

    // MARK: - Auto-sync Settings

    /// Maximum number of retry attempts after a failed sync. Default: `3`.
    public let maxRetries: Int

    /// Initial delay before the first retry. Doubles with each attempt. Default: `.seconds(2)`.
    public let retryBaseDelay: Duration

    /// When `true`, re-syncs on every reachability/foreground event even before the first sync.
    /// When `false` (default), only re-syncs after the first successful sync has completed.
    public let alwaysReactToEvents: Bool

    // MARK: - Init

    /// Creates a new auto-sync configuration.
    ///
    /// - Parameters:
    ///   - server: NTP server hostname. Default: `"time.apple.com"`.
    ///   - timeout: Timeout for a single NTP request. Default: `.seconds(5)`.
    ///   - samples: Number of NTP samples to collect. Default: `4`.
    ///   - logLevel: Diagnostic log verbosity. Default: `.info`.
    ///   - maxRetries: Maximum retry attempts after a failed sync. Default: `3`.
    ///   - retryBaseDelay: Initial retry delay, doubles each attempt. Default: `.seconds(2)`.
    ///   - alwaysReactToEvents: Re-sync on events even before first sync. Default: `false`.
    public init(
        server: String = "time.apple.com",
        timeout: Duration = .seconds(5),
        samples: Int = 4,
        logLevel: GlobalTimeConfig.LogLevel = .info,
        maxRetries: Int = 3,
        retryBaseDelay: Duration = .seconds(2),
        alwaysReactToEvents: Bool = false
    ) {
        self.server = server
        self.timeout = timeout
        self.samples = max(1, samples)
        self.logLevel = logLevel
        self.maxRetries = maxRetries
        self.retryBaseDelay = retryBaseDelay
        self.alwaysReactToEvents = alwaysReactToEvents
    }

    // MARK: - Internal

    var ntpConfig: GlobalTimeConfig {
        GlobalTimeConfig(server: server, timeout: timeout, samples: samples, logLevel: logLevel)
    }
}
