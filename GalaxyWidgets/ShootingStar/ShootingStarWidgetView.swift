import AppIntents
import SwiftUI
import WidgetKit

struct ShootingStarWidgetView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let entry: ShootingStarEntry

    var body: some View {
        Button(intent: LaunchShootingStarIntent()) {
            GeometryReader { geometry in
                let travel = max(0, geometry.size.width - 54)
                ZStack(alignment: .trailing) {
                    Color.clear
                    ShootingStarArtwork()
                        .id(entry.flight)
                        // A new flight starts on the left and settles on the right.
                        // iOS controls playback and may suppress it while the device is locked.
                        .transition(
                            reduceMotion
                                ? .opacity
                                : .asymmetric(
                                    insertion: .offset(x: -travel).combined(with: .opacity),
                                    removal: .opacity))
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
                .animation(reduceMotion ? nil : .easeOut(duration: 1.6), value: entry.flight)
                .clipped()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .containerBackground(for: .widget) { Color.clear }
        .accessibilityLabel("Shooting star")
        .accessibilityHint("Tap to send the star from left to right")
    }
}
