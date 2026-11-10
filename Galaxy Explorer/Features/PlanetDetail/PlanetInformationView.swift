import SwiftUI

// The system sheet supplies navigation and dismissal.
struct PlanetInformationView: View {
    let information: PlanetInformation
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // NASA API CONTENT GOES HERE: Keep these fields empty until actual content is available.
                    if let title = information.title {
                        Text(title).font(.title2.bold()).accessibilityAddTraits(.isHeader)
                    }
                    if let summary = information.summary {
                        Text(summary).font(.headline)
                    }
                    if let detail = information.detail {
                        Text(detail).font(.body)
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
