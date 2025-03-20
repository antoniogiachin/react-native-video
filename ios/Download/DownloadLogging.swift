//
//  DownloadLogging.swift
//  react-native-video
//
//  Created by Davide Balistreri on 17/03/25.
//  Copyright © 2025 Rai - Radiotelevisione Italiana Spa. All rights reserved.
//

import Foundation

protocol DownloadLogging {
    func log(verbose message: String)
    func log(debug message: String)
    func log(info message: String)
    func log(warning message: String)
    func log(error message: String)
}

extension DownloadLogging {
    /// Logs a message if the log level is high enough.
    func log(verbose message: String) {
        log(message, level: .verbose)
    }
    
    /// Logs a message if the log level is high enough.
    func log(debug message: String) {
        log(message, level: .debug)
    }
    
    /// Logs a message if the log level is high enough.
    func log(info message: String) {
        log(message, level: .info)
    }
    
    /// Logs a message if the log level is high enough.
    func log(warning message: String) {
        log(message, level: .warning)
    }
    
    /// Logs a message if the log level is high enough.
    func log(error message: String) {
        log(message, level: .error)
    }
    
    /// Logs a message if the log level is high enough.
    private func log(_ message: String, level: DownloadLoggingLevel) {
        if level >= DownloadManagerModule.logLevel {
            let text = "\(level.prefix) [\(self)] \(message)"
            print(" \(text)")
        }
    }
}

public enum DownloadLoggingLevel: Int, Comparable {
    /// Log everything.
    case verbose = 0
    /// Log debug messages, info messages, errors and warnings.
    case debug = 1
    /// Log info messages, errors and warnings.
    case info = 2
    /// Log errors and warnings.
    case warning = 3
    /// Log errors only.
    case error = 4
    /// Log nothing.
    case none = 5
    
    /// Comparable conformance.
    public static func < (
        lhs: DownloadLoggingLevel,
        rhs: DownloadLoggingLevel
    ) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
    
    /// Color and severity prefix for the log level.
    fileprivate var prefix: String {
        switch self {
        case .verbose:
            return "VERBOSE ⬜️" // silver
        case .debug:
            return "DEBUG 🟩" // green
        case .info:
            return "INFO 🟦" // blue
        case .warning:
            return "WARNING 🟨" // yellow
        case .error:
            return "ERROR 🟥" // red
        case .none:
            return ""
        }
    }
}
