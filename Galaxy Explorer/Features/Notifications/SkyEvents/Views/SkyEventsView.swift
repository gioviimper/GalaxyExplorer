import SwiftUI

struct SkyEventsView: View {
    @ObservedObject private var service = LocalSkyEventService.shared
    var body: some View {
        List {
            Section {
                Text(
                    "Events are screened for the saved area. Times use your device's current time zone. Clear skies and an unobstructed horizon are still needed."
                )
                .foregroundStyle(.secondary)
                if let date = service.lastUpdated {
                    LabeledContent(
                        "Last checked", value: date.formatted(date: .abbreviated, time: .shortened))
                }
                if service.isLoading { ProgressView("Checking NASA and IMCCE…") }
                Button("Refresh events") { service.refreshIfNeeded(force: true) }
                    .disabled(service.isLoading || !service.isEnabled)
            }
            Section("Upcoming near your saved location") {
                if service.events.filter({ $0.startsAt > .now }).isEmpty && !service.isLoading {
                    Text("No upcoming events have been verified for this area yet.").foregroundStyle(
                        .secondary)
                }
                ForEach(service.events.filter { $0.startsAt > .now }) { event in
                    NavigationLink {
                        SkyEventDetailView(event: event)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(event.title).font(.headline)
                            Text(event.startsAt.formatted(date: .abbreviated, time: .shortened))
                                .font(.subheadline).foregroundStyle(.secondary)
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
            }
            if !service.warnings.isEmpty {
                Section("Some sources could not be updated") {
                    ForEach(service.warnings, id: \.self) { Text($0).foregroundStyle(.secondary) }
                }
            }
        }
        .navigationTitle("Sky events")
        .navigationBarTitleDisplayMode(.inline)
        .task { service.refreshIfNeeded() }
    }
}
