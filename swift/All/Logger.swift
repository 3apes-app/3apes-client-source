#if DEBUG
import Foundation
import os

private let logger = Logger(subsystem: "app.threeapes.client.log", category: "debug")

func YGLog(_ message: String) {
    logger.error("\(message, privacy: .public)")
}

#else
func YGLog(_ message: String) {}
#endif
