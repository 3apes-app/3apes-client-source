import AppIntents
import SwiftUI
import WidgetKit

/// 3 APES: the VPN switch for Control Center, the Lock Screen and the
/// Action button (iOS 18).
struct VpnControl: ControlWidget {
    static let kind = "app.threeapes.client.control"

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: Self.kind, provider: Provider()) { isOn in
            ControlWidgetToggle("control.name", isOn: isOn, action: ControlSetVpnIntent()) { on in
                Label(
                    on ? LocalizedStringKey("control.on") : "control.off",
                    systemImage: on ? "lock.shield.fill" : "lock.shield"
                )
            }
            .tint(Color(red: 0.137, green: 0.471, blue: 0.29))
        }
        .displayName("control.name")
        .description("control.description")
    }

    struct Provider: ControlValueProvider {
        var previewValue: Bool { false }

        func currentValue() async throws -> Bool {
            await VpnTunnel.isOn()
        }
    }
}

struct ControlSetVpnIntent: SetValueIntent {
    static var title: LocalizedStringResource { "control.name" }

    @Parameter(title: "VPN")
    var value: Bool

    func perform() async throws -> some IntentResult {
        try await VpnTunnel.set(value)
        return .result()
    }
}
