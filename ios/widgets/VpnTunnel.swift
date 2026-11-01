import ActivityKit
import NetworkExtension

/// 3 APES: the app's VPN profile as the widgets see it. Turning it on uses
/// the connection the app prepared last time (like the switch in iOS
/// Settings); the app must have connected once.
enum VpnTunnel {
    static let tunnelId = "app.threeapes.client.tunnel"

    static func manager() async -> NETunnelProviderManager? {
        let managers = (try? await NETunnelProviderManager.loadAllFromPreferences()) ?? []
        return managers.first {
            ($0.protocolConfiguration as? NETunnelProviderProtocol)?.providerBundleIdentifier == tunnelId
        }
    }

    static func isOn() async -> Bool {
        guard let status = await manager()?.connection.status else { return false }
        return status == .connected || status == .connecting || status == .reasserting
    }

    static func set(_ on: Bool) async throws {
        guard let manager = await manager() else { return }
        if on {
            try manager.connection.startVPNTunnel()
        } else {
            // With "Always on" iOS would bring the VPN straight back.
            if manager.isOnDemandEnabled {
                manager.isOnDemandEnabled = false
                try? await manager.saveToPreferences()
            }
            manager.connection.stopVPNTunnel()
            // The app is not there to notice it: close the activity here.
            for activity in Activity<VpnActivityAttributes>.activities {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
    }
}
