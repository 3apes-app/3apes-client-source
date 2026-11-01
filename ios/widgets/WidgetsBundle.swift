import SwiftUI
import WidgetKit

/// 3 APES: widgets for the Home and Lock Screens, the Control Center
/// switch and the Live Activity (connection time). Texts: Localizable.strings in this folder.
@main
struct ThreeApesWidgets: WidgetBundle {
    var body: some Widget {
        VpnStatusWidget()
        VpnControl()
        VpnLiveActivityWidget()
    }
}
