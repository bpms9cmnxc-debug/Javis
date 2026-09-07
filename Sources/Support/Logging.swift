import Foundation
import os.log

enum JLog {
    static let log = Logger(subsystem: "app.javis.macos", category: "pipeline")

    static func info(_ message: String) {
        log.info("\(message, privacy: .public)")
    }

    static func error(_ message: String) {
        log.error("\(message, privacy: .public)")
    }
}
