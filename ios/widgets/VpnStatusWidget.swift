import AppIntents
import SwiftUI
import WidgetKit

/// 3 APES: VPN state with a button, on the Home Screen (small) and the
/// Lock Screen (circle, line).
struct VpnStatusWidget: Widget {
    static let kind = "app.threeapes.client.status"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: Self.kind, intent: VpnWidgetConfiguration.self, provider: VpnStatusProvider()) { entry in
            VpnStatusView(entry: entry)
                .containerBackground(for: .widget) { WidgetPalette.background }
        }
        .configurationDisplayName("widget.name")
        .description("widget.description")
        .supportedFamilies([.systemSmall, .accessoryCircular, .accessoryRectangular])
    }
}

/// No options; WidgetKit needs a configuration intent for async timelines.
struct VpnWidgetConfiguration: WidgetConfigurationIntent {
    static var title: LocalizedStringResource { "widget.name" }
}

struct VpnStatusEntry: TimelineEntry {
    let date: Date
    let isOn: Bool
}

struct VpnStatusProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> VpnStatusEntry {
        VpnStatusEntry(date: .now, isOn: true)
    }

    func snapshot(for configuration: VpnWidgetConfiguration, in context: Context) async -> VpnStatusEntry {
        VpnStatusEntry(date: .now, isOn: await VpnTunnel.isOn())
    }

    func timeline(for configuration: VpnWidgetConfiguration, in context: Context) async -> Timeline<VpnStatusEntry> {
        let entry = VpnStatusEntry(date: .now, isOn: await VpnTunnel.isOn())
        // The app and the buttons refresh it on every change; this is a backstop.
        return Timeline(entries: [entry], policy: .after(.now.addingTimeInterval(30 * 60)))
    }
}

struct WidgetToggleVpnIntent: AppIntent {
    static var title: LocalizedStringResource { "widget.toggle" }
    static var openAppWhenRun: Bool { false }

    func perform() async throws -> some IntentResult {
        try await VpnTunnel.set(!(await VpnTunnel.isOn()))
        return .result()
    }
}

enum WidgetPalette {
    static let green = Color(red: 0.137, green: 0.471, blue: 0.29)
    // Warm white and the "soft night" card colour of the app.
    static let background = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.098, green: 0.114, blue: 0.141, alpha: 1)
            : UIColor(red: 1, green: 0.984, blue: 0.988, alpha: 1)
    })
}

struct VpnStatusView: View {
    @Environment(\.widgetFamily) private var family
    let entry: VpnStatusEntry

    private var status: LocalizedStringKey { entry.isOn ? "widget.on" : "widget.off" }
    private var symbol: String { entry.isOn ? "lock.shield.fill" : "lock.shield" }

    var body: some View {
        switch family {
        case .accessoryCircular:
            Button(intent: WidgetToggleVpnIntent()) {
                ZStack {
                    AccessoryWidgetBackground()
                    Image(systemName: symbol).font(.title2)
                }
            }
            .buttonStyle(.plain)
        case .accessoryRectangular:
            Button(intent: WidgetToggleVpnIntent()) {
                HStack(spacing: 6) {
                    Image(systemName: symbol).font(.title3)
                    VStack(alignment: .leading, spacing: 0) {
                        Text("3 APES").font(.headline)
                        Text(status).font(.caption)
                    }
                    Spacer(minLength: 0)
                }
            }
            .buttonStyle(.plain)
        default:
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .top) {
                    Image("Monkeys")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 34)
                    Spacer(minLength: 0)
                    Image(systemName: symbol)
                        .font(.title3)
                        .foregroundStyle(entry.isOn ? WidgetPalette.green : .secondary)
                }
                Spacer(minLength: 0)
                Text(status)
                    .font(.headline)
                    .foregroundStyle(entry.isOn ? WidgetPalette.green : .primary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                Button(intent: WidgetToggleVpnIntent()) {
                    Text(entry.isOn ? LocalizedStringKey("widget.turnOff") : "widget.turnOn")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(entry.isOn ? .secondary : WidgetPalette.green)
            }
        }
    }
}
