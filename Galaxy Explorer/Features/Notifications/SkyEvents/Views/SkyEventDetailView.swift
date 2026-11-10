import SwiftUI

struct SkyEventDetailView: View {
    let event: SkyEvent
    var body: some View {
        List {
            Section {
                Text(event.title).font(.title2.bold())
                LabeledContent(
                    "Viewing time", value: event.startsAt.formatted(date: .abbreviated, time: .shortened))
                Text(event.summary)
            }
            Section {
                Link("Read the NASA source", destination: event.sourceURL)
                if let url = event.calculationURL {
                    Link("View IMCCE calculation", destination: url)
                }
            } header: {
                Text("Sources")
            } footer: {
                Text(
                    "Visibility is an astronomical estimate for your saved area, not a weather forecast. Local terrain, buildings, clouds and light pollution are not included."
                )
            }
        }
        .navigationTitle("Sky event")
        .navigationBarTitleDisplayMode(.inline)
    }
}
