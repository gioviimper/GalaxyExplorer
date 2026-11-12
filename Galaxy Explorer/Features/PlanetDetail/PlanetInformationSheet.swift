import SwiftUI

// Keep the original system presentation; card selection is handled by the planet scene.
struct PlanetInformationSheet: View {
    let information: PlanetInformation
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var detent: PresentationDetent = .medium

    var body: some View {
        NavigationStack {
            PlanetInformationView(information: information)
                .navigationTitle(information.planetName)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { dismiss() }
                    }
                }
        }
        .presentationDetents([.medium, .large], selection: $detent)
        .presentationDragIndicator(.visible)
        .onAppear {
            if typeSize.isAccessibilitySize { detent = .large }
        }
        .onChange(of: typeSize) { _, size in
            if size.isAccessibilitySize { detent = .large }
        }
    }
}
