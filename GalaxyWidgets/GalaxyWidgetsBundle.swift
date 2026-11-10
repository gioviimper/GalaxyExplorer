import SwiftUI
import WidgetKit

// I keep Home and Lock Screen widgets together in a single extension.
@main
struct GalaxyWidgetsBundle: WidgetBundle {
    var body: some Widget {
        PlanetExplorerWidget()
        ShootingStarWidget()
    }
}
