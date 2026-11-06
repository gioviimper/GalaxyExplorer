import WidgetKit

// I keep the reference facts here so the widget works offline.
struct MarsEntry: TimelineEntry {
    let date: Date
    let gravity: String
    let temperature: String
    static let sample = MarsEntry(date: .now, gravity: "3.7 m/s²", temperature: "−65 °C")
}

struct MarsProvider: TimelineProvider {
    func placeholder(in context: Context) -> MarsEntry { .sample }
    func getSnapshot(in context: Context, completion: @escaping (MarsEntry) -> Void) {
        completion(.sample)
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<MarsEntry>) -> Void) {
        // NASA API CONTENT GOES HERE: Load validated content from a content service
        // or a shared offline cache. Never fetch from a widget's SwiftUI body.
        // Keep a bundled fallback and store source URLs and update dates with API data.
        // These values are reference facts, not live temperature measurements.
        completion(Timeline(entries: [.sample], policy: .never))
    }
}

