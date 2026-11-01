import ActivityKit
import Flutter
import LocalAuthentication
import NetworkExtension
import Security
import UIKit
import WidgetKit

@main
@objc class AppDelegate: FlutterAppDelegate, @preconcurrency FlutterImplicitEngineDelegate {
    private var vpnStatusObserver: NSObjectProtocol?
    private var activeObserver: NSObjectProtocol?

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        // 3 APES: the widget and the Control Center switch follow the VPN.
        vpnStatusObserver = NotificationCenter.default.addObserver(
            forName: .NEVPNStatusDidChange, object: nil, queue: .main
        ) { note in
            WidgetCenter.shared.reloadAllTimelines()
            if #available(iOS 18.0, *) {
                ControlCenter.shared.reloadAllControls()
            }
            // 3 APES: connection time in the Dynamic Island and on the Lock Screen.
            if #available(iOS 16.2, *), let connection = note.object as? NEVPNConnection {
                let status = connection.status
                let connectedAt = connection.connectedDate
                Task { await VpnLiveActivity.update(status, connectedAt: connectedAt) }
            }
        }
        // Back in the app: start the activity for a VPN switched on elsewhere,
        // or close one left after the VPN went off while the app slept.
        activeObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main
        ) { _ in
            if #available(iOS 16.2, *) {
                Task { await VpnLiveActivity.syncFromSystem() }
            }
        }
        
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
    
    func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
        let binaryMessenger = engineBridge.applicationRegistrar.messenger()
        let flutterApi = AppFlutterApi(binaryMessenger: binaryMessenger)
        BridgeHostApiSetup.setUp(binaryMessenger: binaryMessenger, api: AppHostApi(flutterApi: flutterApi))
        
        // 3 APES: iOS side of the shared device channel (Android: MainActivity.kt).
        let deviceChannel = FlutterMethodChannel(
            name: "app.threeapes.client/device",
            binaryMessenger: binaryMessenger
        )
        deviceChannel.setMethodCallHandler { call, result in
            switch call.method {
            case "iosDeviceId":
                result(DeviceIdKeychain.read())
            // 3 APES: security check — passcode, Face ID / Touch ID, iOS version.
            case "deviceSecurity":
                result(DeviceSecurity.read())
            default:
                result(FlutterError(code: "unimplemented", message: call.method, details: nil))
            }
        }
        
        GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    }
}

/// 3 APES: the Live Activity of a running VPN. The same type is declared in
/// the widgets extension (ios/widgets/VpnLiveActivity.swift), which draws it.
@available(iOS 16.1, *)
struct VpnActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var connectedAt: Date
    }
}

/// Starts, updates and ends the activity from the VPN status. iOS lets an
/// app start it only while in front; ending works from the background too.
@available(iOS 16.2, *)
enum VpnLiveActivity {
    /// Off for now: on the Lock Screen it is too much; decide at the cosmetics stage.
    static let enabled = false

    static func update(_ status: NEVPNStatus, connectedAt: Date?) async {
        let current = Activity<VpnActivityAttributes>.activities
        guard enabled else {
            for activity in current { await activity.end(nil, dismissalPolicy: .immediate) }
            return
        }
        switch status {
        case .connected:
            let state = VpnActivityAttributes.ContentState(connectedAt: connectedAt ?? .now)
            if let activity = current.first {
                guard activity.content.state != state else { return }
                await activity.update(ActivityContent(state: state, staleDate: nil))
            } else if ActivityAuthorizationInfo().areActivitiesEnabled {
                _ = try? Activity.request(
                    attributes: VpnActivityAttributes(),
                    content: ActivityContent(state: state, staleDate: nil)
                )
            }
        case .disconnected, .invalid:
            for activity in current {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        default:
            break
        }
    }

    static func syncFromSystem() async {
        let managers = (try? await NETunnelProviderManager.loadAllFromPreferences()) ?? []
        let connection = managers.first {
            ($0.protocolConfiguration as? NETunnelProviderProtocol)?.providerBundleIdentifier
                == "app.threeapes.client.tunnel"
        }?.connection
        await update(connection?.status ?? .disconnected, connectedAt: connection?.connectedDate)
    }
}

/// 3 APES: what the security check may read on iOS. Public APIs only:
/// whether a passcode is set, which biometry is enrolled, the iOS version.
enum DeviceSecurity {
    static func read() -> [String: Any] {
        let version = ProcessInfo.processInfo.operatingSystemVersion
        var info: [String: Any] = [
            "osVersion": version.patchVersion == 0
                ? "\(version.majorVersion).\(version.minorVersion)"
                : "\(version.majorVersion).\(version.minorVersion).\(version.patchVersion)",
        ]
        let context = LAContext()
        var error: NSError?
        let passcode = context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error)
        if passcode {
            info["screenLock"] = true
            if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil) {
                switch context.biometryType {
                case .faceID: info["biometry"] = "Face ID"
                case .touchID: info["biometry"] = "Touch ID"
                default: break
                }
            }
        } else if error?.code == LAError.passcodeNotSet.rawValue {
            info["screenLock"] = false
        }
        return info
    }
}

/// 3 APES: random device ID kept in the Keychain for a stable `x-hwid`.
/// It survives app reinstalls, stays on this iPhone only (no iCloud sync,
/// not restored to another device) and is hashed with the app salt in Dart,
/// so the raw value never leaves the phone.
enum DeviceIdKeychain {
    private static let service = "app.threeapes.client.hwid"
    private static let account = "device-id-v1"

    static func read() -> String? {
        if let existing = load() { return existing }
        let id = UUID().uuidString.lowercased()
        return save(id) ? id : load()
    }

    private static func load() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data,
              let value = String(data: data, encoding: .utf8),
              !value.isEmpty
        else { return nil }
        return value
    }

    private static func save(_ value: String) -> Bool {
        let attributes: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: Data(value.utf8),
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]
        return SecItemAdd(attributes as CFDictionary, nil) == errSecSuccess
    }
}
