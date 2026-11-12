import SwiftUI

// MARK: - Preview screen

struct PlanetAtmospherePreview: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var selectedPlanet: Planet = .jupiter

    private let planets: [Planet] = [
        .mercury,
        .venus,
        .earth,
        .mars,
        .jupiter,
        .saturn,
        .uranus,
        .neptune,
    ]

    var body: some View {
        VStack(spacing: 16) {
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(selectedPlanet.name)
                        .font(.largeTitle.bold())

                    Text("Drag to explore · Pinch to zoom")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)

                Menu {
                    ForEach(planets, id: \.id) { planet in
                        Button {
                            selectedPlanet = planet
                        } label: {
                            if selectedPlanet.id == planet.id {
                                Label(
                                    planet.name,
                                    systemImage: "checkmark"
                                )
                            } else {
                                Text(planet.name)
                            }
                        }
                    }
                } label: {
                    Image(systemName: "globe")
                        .font(.title2)
                        .frame(minWidth: 44, minHeight: 44)
                }
                .accessibilityLabel("Choose a planet")
            }
            .padding(.horizontal)

            PlanetAtmosphereScene(
                planet: selectedPlanet,
                isActive: scenePhase == .active,
                animateAtmosphere: !reduceMotion
            )
            // Rebuild the scene when a different planet is selected.
            .id(selectedPlanet.id)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityLabel(
                "Interactive 3D model of \(selectedPlanet.name)"
            )
            .accessibilityHint(
                "Drag to change the view. Pinch to zoom."
            )

            if reduceMotion {
                Text("Atmospheric animation is paused with Reduce Motion.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
            }
        }
        .padding(.vertical)
        .background(.black)
        .preferredColorScheme(.dark)
    }
}

#Preview {
    PlanetAtmospherePreview()
}
