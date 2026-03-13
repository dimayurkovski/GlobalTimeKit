//
//  GTKLogger.swift
//  GlobalTimeKit
//
//  Created by Dmitry Yurkovski on 12/03/2026.
//

import Foundation
import os

/// Internal logger for GlobalTimeKit with configurable verbosity.
///
/// All log messages go through Apple's `os.Logger` (subsystem `com.globaltimekit`)
/// and are visible in Console.app.
internal struct GTKLogger: Sendable {

    private static let logger = Logger(subsystem: "com.globaltimekit", category: "GlobalTimeKit")

    private let level: GlobalTimeConfig.LogLevel

    init(level: GlobalTimeConfig.LogLevel) {
        self.level = level
    }

    func log(_ messageLevel: GlobalTimeConfig.LogLevel, _ message: String) {
        guard level >= messageLevel else { return }
        switch messageLevel {
        case .none:    break
        case .error:   Self.logger.error("\(message, privacy: .public)")
        case .warning: Self.logger.warning("\(message, privacy: .public)")
        case .info:    Self.logger.info("\(message, privacy: .public)")
        case .debug:   Self.logger.debug("\(message, privacy: .public)")
        }
    }
}
