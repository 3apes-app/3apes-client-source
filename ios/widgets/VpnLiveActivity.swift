import ActivityKit
import AppIntents
import SwiftUI
import WidgetKit

/// 3 APES: same type as in the app (ios/Runner/AppDelegate.swift), which
/// starts and ends the activity; ActivityKit matches them by name.
struct VpnActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var connectedAt: Date
    }
}

/// 3 APES: connection time in the Dynamic Island and on the Lock Screen,
/// with a button that turns the VPN off.
struct VpnLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: VpnActivityAttributes.self) { context in
            HStack(spacing: 12) {
                Image("Monkeys")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 36)
                VStack(alignment: .leading, spacing: 2) {
                    Text("3 APES").font(.headline)
                    Text("widget.on")
                        .font(.subheadline)
                        .foregroundStyle(WidgetPalette.green)
                }
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 4) {
                    VpnTimer(since: context.state.connectedAt)
                        .font(.title3.weight(.semibold))
                    Button(intent: WidgetToggleVpnIntent()) {
                        Text("widget.turnOff").font(.caption.weight(.semibold))
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding(16)
            .activityBackgroundTint(WidgetPalette.background)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label("3 APES", systemImage: "lock.shield.fill")
                        .font(.headline)
                        .foregroundStyle(WidgetPalette.green)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    VpnTimer(since: context.state.connectedAt)
                        .font(.title3.weight(.semibold))
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        Text("widget.on").foregroundStyle(.secondary)
                        Spacer()
                        Button(intent: WidgetToggleVpnIntent()) {
                            Text("widget.turnOff")
                        }
                        .buttonStyle(.bordered)
                    }
                }
            } compactLeading: {
                Image(systemName: "lock.shield.fill").foregroundStyle(WidgetPalette.green)
            } compactTrailing: {
                VpnTimer(since: context.state.connectedAt)
                    .frame(maxWidth: 52)
            } minimal: {
                Image(systemName: "lock.shield.fill").foregroundStyle(WidgetPalette.green)
            }
        }
    }
}

/// Counts up from the moment the VPN connected; iOS ticks it by itself.
struct VpnTimer: View {
    let since: Date

    var body: some View {
        Text(timerInterval: since...Date.distantFuture, countsDown: false)
            .monospacedDigit()
            .multilineTextAlignment(.trailing)
    }
}
