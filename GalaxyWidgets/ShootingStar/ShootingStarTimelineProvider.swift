import WidgetKit

struct ShootingStarTimelineProvider: TimelineProvider {
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
