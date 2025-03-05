//
//  Logger.swift
//  react-native-video
//
//  Created by Valerio CARMINE IENCO (KINETON) on 19/11/24.
//

import Foundation


public enum LoggerLevel: Int, CustomStringConvertible {
    
    case trace
    case debug
    case info
    case warning
    case error
    case fatal
    
    public var description: String {
       get {
         switch self {
            case .trace:
                return "TRACE"
            case .debug:
                return "DEBUG"
            case .info:
                return "INFO "
            case .warning:
                return "WARN "
            case .error:
                return "ERROR"
            case .fatal:
                return "FATAL"
         }
       }
     }
}

public class Logger {
    
    public var level: LoggerLevel = .fatal
    
    public func setup(level: LoggerLevel){
        self.level = level
    }
    
    public func logCurrentClass(_ fileStr: String) -> String {
        let fileName = fileStr.components(separatedBy: "/").last ?? ""
        return fileName.components(separatedBy:".").first ?? ""
    }
    
    public func log(level: LoggerLevel, _ text: String, file: String = #file, function: String = #function, line: Int = #line){
        if level.rawValue >= level.rawValue {
            let theFileName = logCurrentClass(file)
            print("\(level) [\(theFileName).\(function):\(line)] \(text)")
        }
    }

    public func trace(_ text: String, file: String = #file, function: String = #function, line: Int = #line){
        log(level: .trace, text, file: file, function: function, line: line)
    }
    
    public func debug(_ text: String, file: String = #file, function: String = #function, line: Int = #line){
        log(level: .debug, text, file: file, function: function, line: line)
    }
    
    public func info(_ text: String, file: String = #file, function: String = #function, line: Int = #line){
        log(level: .info, text, file: file, function: function, line: line)
    }
    
    public func warning(_ text: String, file: String = #file, function: String = #function, line: Int = #line){
        log(level: .warning, text, file: file, function: function, line: line)
    }
    
    public func error(_ text: String, file: String = #file, function: String = #function, line: Int = #line){
        log(level: .error, text, file: file, function: function, line: line)
    }
    
    public func fatal(_ text: String, file: String = #file, function: String = #function, line: Int = #line){
        log(level: .fatal, text, file: file, function: function, line: line)
    }
}

public var logger: Logger = Logger()

