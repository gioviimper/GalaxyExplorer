import SwiftUI

// Content stays separate from presentation so the planet scene is never replaced.
struct PlanetInformationView: View {
    let information: PlanetInformation

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // NASA imagery remains above the title and description.
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
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
        .scrollContentBackground(.hidden)
    }
}
