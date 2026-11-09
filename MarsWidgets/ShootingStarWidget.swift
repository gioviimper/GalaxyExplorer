import SwiftUI
import WidgetKit
import AppIntents

// I keep this small interaction inside the extension, so it also works offline.
private enum ShootingStarState {
    static let key = "shootingStarFlight"
    static var flight: Int { UserDefaults.standard.integer(forKey: key) }
}

struct LaunchShootingStarIntent: AppIntent {
    static var title: LocalizedStringResource = "Launch Shooting Star"
    static var description = IntentDescription("Send a shooting star across the widget.")
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult {
        UserDefaults.standard.set(ShootingStarState.flight &+ 1, forKey: ShootingStarState.key)
        // WidgetKit reloads the timeline after this interactive intent finishes.
        return .result()
    }
}

struct ShootingStarEntry: TimelineEntry {
    let date: Date
    let flight: Int
}

struct ShootingStarProvider: TimelineProvider {
    func placeholder(in context: Context) -> ShootingStarEntry {
        ShootingStarEntry(date: .now, flight: 0)
    }

    func getSnapshot(in context: Context, completion: @escaping (ShootingStarEntry) -> Void) {
        completion(ShootingStarEntry(date: .now, flight: ShootingStarState.flight))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ShootingStarEntry>) -> Void) {
        let entry = ShootingStarEntry(date: .now, flight: ShootingStarState.flight)
        // I only refresh after an interaction; no timers or repeated background reloads.
        completion(Timeline(entries: [entry], policy: .never))
    }
}

private struct ShootingStarArtwork: View {
    var body: some View {
        ZStack(alignment: .trailing) {
            // The tail fades towards the left and travels together with the star.
            Capsule()
                .fill(LinearGradient(colors: [.clear, .primary.opacity(0.75)],
                                     startPoint: .leading, endPoint: .trailing))
                .frame(width: 34, height: 2)
                .offset(x: -12)
            Capsule()
                .fill(LinearGradient(colors: [.clear, .primary.opacity(0.35)],
                                     startPoint: .leading, endPoint: .trailing))
                .frame(width: 22, height: 1)
                .offset(x: -16, y: 5)
            Image(systemName: "sparkle")
                .resizable()
                .scaledToFit()
                .frame(width: 23, height: 23)
        }
        .frame(width: 54, height: 34)
        .accessibilityHidden(true)
    }
}

private struct ShootingStarEntryView: View {
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
                        .transition(reduceMotion ? .opacity : .asymmetric(
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

struct ShootingStarWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "ShootingStarWidget", provider: ShootingStarProvider()) { entry in
            ShootingStarEntryView(entry: entry)
        }
        .configurationDisplayName("Shooting Star")
        .description("Tap to send a little starlight across your Lock Screen.")
        .supportedFamilies([.accessoryRectangular])
    }
}

#Preview("Horizontal Lock Screen", as: .accessoryRectangular) {
    ShootingStarWidget()
} timeline: {
    ShootingStarEntry(date: .now, flight: 0)
    ShootingStarEntry(date: .now.addingTimeInterval(5), flight: 1)
}
