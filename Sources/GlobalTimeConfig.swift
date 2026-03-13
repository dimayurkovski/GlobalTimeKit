//
//  GlobalTimeConfig.swift
//  GlobalTimeKit
//
//  Created by Dmitry Yurkovski on 11/03/2026.
//

import Foundation

/// Configuration for ``GlobalTimeClient``.
///
/// Controls which NTP server to query, how long to wait for a response,
/// and how many samples to collect for accuracy.
///
/// ```swift
/// // Default configuration: time.apple.com, 5s timeout, 4 samples
/// let config = GlobalTimeConfig()
///
/// // Custom configuration
/// let config = GlobalTimeConfig(
///     server: "time.apple.com",
///     timeout: .seconds(10),
///     samples: 6
/// )
/// ```
public struct GlobalTimeConfig: Sendable {

    /// Controls the verbosity of diagnostic log output in Console.app.
    ///
    /// Logs use Apple's `os.Logger` (subsystem `com.globaltimekit`)
    /// and are zero-cost when not captured.
    ///
    /// ```swift
    /// // Silent — no log output
    /// let config = GlobalTimeConfig(logLevel: .none)
    ///
    /// // Verbose — see every sample result
    /// let config = GlobalTimeConfig(logLevel: .debug)
    /// ```
    public enum LogLevel: Int, Sendable, Comparable {
        /// No log output.
        case none = 0
        /// Errors only (all samples failed).
        case error = 1
        /// Errors and warnings (individual sample failures).
        case warning = 2
        /// Errors, warnings, and informational messages (sync start/complete).
        case info = 3
        /// All messages including per-sample details.
        case debug = 4

        public static func < (lhs: LogLevel, rhs: LogLevel) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
    }

    /// NTP server hostname. Default: `"time.apple.com"`.
    public let server: String

    /// Timeout for a single NTP request. Default: `.seconds(5)`.
    public let timeout: Duration

    /// Number of NTP samples to collect during ``GlobalTimeClient/sync()``.
    /// The sample with the lowest round-trip delay is selected for maximum accuracy.
    /// Default: `4`.
    public let samples: Int

    /// Diagnostic log verbosity. Default: `.info`.
    public let logLevel: LogLevel

    /// Creates a new configuration.
    ///
    /// - Parameters:
    ///   - server: NTP server hostname. Default: `"time.apple.com"`.
    ///   - timeout: Timeout for a single NTP request. Default: `.seconds(5)`.
    ///   - samples: Number of NTP samples to collect. Default: `4`.
    ///   - logLevel: Diagnostic log verbosity. Default: `.info`.
    public init(
        server: String = "time.apple.com",
        timeout: Duration = .seconds(5),
        samples: Int = 4,
        logLevel: LogLevel = .info
    ) {
        self.server = server
        self.timeout = timeout
        self.samples = max(1, samples)
        self.logLevel = logLevel
    }
}
