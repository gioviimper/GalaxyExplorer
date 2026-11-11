import SwiftUI

// The system sheet supplies navigation and dismissal.
struct PlanetInformationView: View {
    let information: PlanetInformation
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let url = information.imageURL {
                        NASAContentImageView(url: url)
                    }
                    if let title = information.title {
                        Text(title).font(.title2.bold()).accessibilityAddTraits(.isHeader)
                    }
                    if information.detail == nil, let summary = information.summary {
                        Text(summary).font(.headline)
                    }
                    if let detail = information.detail {
                        Text(detail).font(.body)
                    }
                    if let credit = information.credit {
                        Text("Credit: \(credit)").font(.caption).foregroundStyle(.secondary)
                    }
                    if let source = information.sourceURL {
                        Link("View on NASA Image and Video Library", destination: source)
                        Text("Library content is not mapped to the surface points shown in the 3D view.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
            }
            .navigationTitle(information.planetName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}
