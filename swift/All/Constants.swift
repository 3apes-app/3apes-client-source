import Foundation

public let ProxyHost = "127.0.0.1"
public let TunMtu: NSNumber = 1500

public let StartModelFile = "run/start.json"

public enum Constants {
    #if SYSTEM_EXTENSION
    public static let useSystemExtension = true
    #else
    public static let useSystemExtension = false
    #endif
}

private let teamAppGroupId = "Q6N4RTRU4L.app.threeapes.client"
private let groupAppGroupId = "group.app.threeapes.client"
private let seGroupAppGroupId = "group.app.threeapes.client.se"

public func appGroupId() -> String {
    #if os(iOS)
        return groupAppGroupId
    #elseif os(macOS)
        if Constants.useSystemExtension {
            return seGroupAppGroupId
        } else {
            return teamAppGroupId
        }
    #endif
}

private let tunId = "app.threeapes.client.tunnel"
private let seTunId = "app.threeapes.client.se.tunnel"

public func packetTunnelId() -> String {
    #if os(iOS)
        return tunId
    #elseif os(macOS)
        if Constants.useSystemExtension {
            return seTunId
        } else {
            return tunId
        }
    #endif
}

private let serverAddress = "3 APES"
private let seServerAddress = "3 APES SE"

public func vpnServerAddress() -> String {
    #if os(iOS)
        return serverAddress
    #elseif os(macOS)
        if Constants.useSystemExtension {
            return seServerAddress
        } else {
            return serverAddress
        }
    #endif
}

public func extensionGroupContainerURL() -> URL? {
    #if os(macOS)
    if Constants.useSystemExtension {
        return URL(fileURLWithPath: "/private/var/root/Library/Group Containers/\(appGroupId())")
    }
    #endif
    return FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupId())
}
