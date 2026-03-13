//
//  GlobalTimeError.swift
//  GlobalTimeKit
//
//  Created by Dmitry Yurkovski on 11/03/2026.
//

import Foundation

/// Errors that can occur during NTP time synchronization.
///
/// `GlobalTimeError` covers all failure scenarios when communicating
/// with an NTP server, from network-level issues to malformed responses.
///
/// ```swift
/// do {
///     try await client.sync()
/// } catch let error as GlobalTimeError {
///     switch error {
///     case .timeout:
///         print("Request timed out")
///     case .invalidResponse:
///         print("Server returned an invalid NTP packet")
///     case .dnsResolutionFailed:
///         print("Could not resolve server hostname")
///     case .networkUnavailable:
///         print("No network connection")
///     case .serverUnreachable:
///         print("NTP server is unreachable")
///     }
/// }
/// ```
public enum GlobalTimeError: Error, Sendable, Equatable, LocalizedError {

    /// The NTP request did not receive a response within the configured timeout.
    case timeout

    /// The server response could not be parsed as a valid NTP packet.
    case invalidResponse

    /// The NTP server hostname could not be resolved via DNS.
    case dnsResolutionFailed

    /// The device has no active network connection.
    case networkUnavailable

    /// The NTP server could not be reached (e.g. connection refused or reset).
    case serverUnreachable

    public var errorDescription: String? {
        switch self {
        case .timeout:
            return "NTP request timed out"
        case .invalidResponse:
            return "Invalid NTP server response"
        case .dnsResolutionFailed:
            return "Could not resolve NTP server hostname"
        case .networkUnavailable:
            return "No network connection available"
        case .serverUnreachable:
            return "NTP server is unreachable"
        }
    }
}
