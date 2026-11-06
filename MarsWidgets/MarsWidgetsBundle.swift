import WidgetKit
import SwiftUI

// I keep Home and Lock Screen widgets together in a single extension.
@main
struct MarsWidgetsBundle: WidgetBundle {
    var body: some Widget {
        MarsWidgets()
        ShootingStarWidget()
    }
}
