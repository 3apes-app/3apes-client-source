import AppIntents
import Foundation

// 3 APES: Siri, the Shortcuts app and the Action button. The actions run
// without opening the app and use the connection the app prepared last time
// (like the VPN switch in iOS Settings). Texts: Localizable.strings, Siri
// phrases: AppShortcuts.strings.

@available(iOS 16.0, *)
struct ConnectVpnIntent: AppIntent {
    static var title: LocalizedStringResource { "intent.connect.title" }
    static var description: IntentDescription { IntentDescription("intent.connect.description") }
    static var openAppWhenRun: Bool { false }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        .result(dialog: IntentDialog(await VpnIntentRunner.connect()))
    }
}

@available(iOS 16.0, *)
struct DisconnectVpnIntent: AppIntent {
    static var title: LocalizedStringResource { "intent.disconnect.title" }
    static var description: IntentDescription { IntentDescription("intent.disconnect.description") }
    static var openAppWhenRun: Bool { false }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        .result(dialog: IntentDialog(await VpnIntentRunner.disconnect()))
    }
}

@available(iOS 16.0, *)
struct ToggleVpnIntent: AppIntent {
    static var title: LocalizedStringResource { "intent.toggle.title" }
    static var description: IntentDescription { IntentDescription("intent.toggle.description") }
    static var openAppWhenRun: Bool { false }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        .result(dialog: IntentDialog(await VpnIntentRunner.toggle()))
    }
}

@available(iOS 16.0, *)
struct ThreeApesShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: ConnectVpnIntent(),
            phrases: [
                "Connect \(.applicationName)",
                "Turn on \(.applicationName)",
            ]
        )
        AppShortcut(
            intent: DisconnectVpnIntent(),
            phrases: [
                "Disconnect \(.applicationName)",
                "Turn off \(.applicationName)",
            ]
        )
        AppShortcut(
            intent: ToggleVpnIntent(),
            phrases: [
                "Toggle \(.applicationName)",
            ]
        )
    }
}

/// Runs the commands through the same VPNManager the app uses.
@available(iOS 16.0, *)
@MainActor
enum VpnIntentRunner {
    /// nil: the VPN profile is not set up yet (the app was never connected).
    private static func isOn() async -> Bool? {
        let permission = await VPNManager.shared.queryPlatformPermission()
        guard permission.state == .granted else { return nil }
        let status = try? await VPNManager.shared.readVpnStatus()
        return status == .connected || status == .connecting
    }

    static func connect() async -> LocalizedStringResource {
        guard let on = await isOn(), StartVpnRequest.startModel != nil else {
            return "intent.result.needApp"
        }
        if on { return "intent.result.alreadyConnected" }
        let result = await VPNManager.shared.startVpn()
        return result.state == .success ? "intent.result.connected" : "intent.result.failed"
    }

    static func disconnect() async -> LocalizedStringResource {
        guard let on = await isOn() else { return "intent.result.needApp" }
        if !on { return "intent.result.alreadyDisconnected" }
        let result = await VPNManager.shared.stopVpn()
        return result.state == .success ? "intent.result.disconnected" : "intent.result.failed"
    }

    static func toggle() async -> LocalizedStringResource {
        guard let on = await isOn() else { return "intent.result.needApp" }
        return on ? await disconnect() : await connect()
    }
}
