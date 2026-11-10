import SwiftUI

struct SolarSystemHomeView: View {
    @State private var path: [Planet] = []
    @ObservedObject private var notifications = AppNotificationService.shared
    @ObservedObject private var sky = LocalSkyEventService.shared
    @Environment(\.scenePhase) private var scenePhase
    @State private var request: PlanetViewRequest?
    @State private var isActive = true
    @Environment(\.dynamicTypeSize) private var typeSize
    @AppStorage("hapticFeedbackEnabled") private var hapticsEnabled = true

    var body: some View {
        NavigationStack(path: $path) {
            GeometryReader { geometry in
                if typeSize.isAccessibilitySize {
                    ScrollView {
                        overview.frame(minHeight: geometry.size.height)
                    }
                } else {
                    overview
                }
            }
            .background(.black)
            .navigationTitle("Solar System")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        ForEach(Planet.all) { planet in
                            Button(planet.name) {
                                isActive = false
                                path.append(planet)
                            }
                        }
                    } label: {
                        Label("Choose celestial body", systemImage: "globe")
                            .frame(minWidth: 44, minHeight: 44)
                    }
                    .accessibilityLabel("Choose celestial body")
                    .accessibilityHint("Choose the Sun or any planet without using the 3D model")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        ForEach(PlanetViewAction.allCases) { action in
                            Button {
                                request = PlanetViewRequest(action: action)
                            } label: {
                                Label(action.title, systemImage: action.symbol)
                            }
                        }
                        NavigationLink {
                            NotificationSettingsView()
                        } label: {
                            Label("Notifications", systemImage: "bell")
                        }
                        Divider()
                        Toggle("Haptic feedback", isOn: $hapticsEnabled)
                    } label: {
                        Label("View controls", systemImage: "slider.horizontal.3")
                            .frame(minWidth: 44, minHeight: 44)
                    }
                    .accessibilityLabel("View controls")
                    .accessibilityHint("Rotate, zoom, reset the model, or change haptic feedback")
                }
            }
            .navigationDestination(for: Planet.self) { planet in
                PlanetDetailView(planet: planet)
                    .navigationBarTitleDisplayMode(.inline)
            }
            .sheet(item: $sky.selectedEvent) { event in SkyEventNotificationSheet(event: event) }
            .task {
                await notifications.refresh()
                openNotificationDestination()
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { Task { await notifications.refresh() } }
            }
            .onChange(of: notifications.destination) { _, _ in openNotificationDestination() }
            .onAppear { isActive = true }
            .onDisappear { isActive = false }
        }
        .preferredColorScheme(.dark)
    }

    private func openNotificationDestination() {
        guard let id = notifications.destination,
            let planet = Planet.all.first(where: { $0.id == id })
        else { return }
        path = [planet]
        isActive = false
        notifications.destination = nil
    }

    private var overview: some View {
        VStack(spacing: 12) {
            Text("Tap a celestial body to explore")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
            SolarSystem3DView(isActive: isActive, hapticsEnabled: hapticsEnabled, request: request) {
                planet in
                guard path.isEmpty else { return }
                isActive = false
                path.append(planet)
            }
            .frame(
                maxWidth: .infinity, minHeight: typeSize.isAccessibilitySize ? 360 : 0, maxHeight: .infinity
            )
            .clipped()
            VStack(spacing: 4) {
                Text("Drag to rotate · Pinch to zoom").font(.caption)
                Text("Not to scale").font(.caption2)
            }
            .foregroundStyle(.secondary)
            .padding(.horizontal)
            .padding(.bottom, 12)
        }
    }
}

#Preview("Solar System Home") { SolarSystemHomeView() }

#Preview("Home - Accessibility Text") {
    SolarSystemHomeView().environment(\.dynamicTypeSize, .accessibility3)
}
