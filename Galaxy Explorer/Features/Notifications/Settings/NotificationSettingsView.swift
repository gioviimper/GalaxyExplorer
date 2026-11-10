import SwiftUI
import UserNotifications

struct NotificationSettingsView: View {
    @ObservedObject private var service = AppNotificationService.shared
    @ObservedObject private var sky = LocalSkyEventService.shared
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("planetFactsEnabled") private var factsEnabled = false
    @AppStorage("planetFactInterval") private var interval = 3
    @AppStorage("planetFactHour") private var hour = 19
    @AppStorage("planetFactMinute") private var minute = 0

    private var time: Binding<Date> {
        Binding(
            get: {
                Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: .now) ?? .now
            },
            set: {
                hour = Calendar.current.component(.hour, from: $0)
                minute = Calendar.current.component(.minute, from: $0)
                service.reschedule()
            })
    }

    var body: some View {
        Form {
            Section {
                if service.authorization == .notDetermined {
                    Button("Allow notifications") { Task { await service.requestPermission() } }
                } else if service.authorization == .denied {
                    Text("Notifications are disabled in iOS Settings.")
                    Link("Open Settings", destination: URL(string: UIApplication.openSettingsURLString)!)
                } else {
                    Label("Notifications allowed", systemImage: "checkmark.circle")
                }
            } footer: {
                Text("Choose what you want to receive. You can change these preferences at any time.")
            }
            Section {
                Toggle("Planet facts", isOn: $factsEnabled)
                if factsEnabled {
                    Picker("Frequency", selection: $interval) {
                        Text("Daily").tag(1)
                        Text("Every 3 days").tag(3)
                        Text("Weekly").tag(7)
                    }
                    DatePicker("Delivery time", selection: time, displayedComponents: .hourAndMinute)
                }
            } header: {
                Text("Planet facts")
            } footer: {
                Text(
                    "Discover a different planet with each reminder. Reminders are scheduled for up to 60 days and renewed when you open the app."
                )
            }
            Section {
                Toggle("Local sky events", isOn: Binding(get: { sky.isEnabled }, set: { sky.setEnabled($0) }))
                if sky.isEnabled {
                    Button("Use my current location") { sky.useCurrentLocation() }
                    if let message = sky.locationMessage { Text(message).foregroundStyle(.secondary) }
                    if sky.isLoading { ProgressView("Checking NASA and IMCCE…") }
                    NavigationLink("Upcoming events") { SkyEventsView() }
                    Button("Turn off and forget my location", role: .destructive) { sky.forgetLocation() }
                }
            } header: {
                Text("Sky events")
            } footer: {
                Text(
                    "Enable to share an approximate location with IMCCE for visibility calculations. NASA supplies meteor dates and eclipse catalogs. No continuous tracking. Alerts arrive about one hour before a viewing opportunity; new dates are checked when you open the app."
                )
            }
            if let message = service.errorMessage {
                Section("Unable to update notifications") { Text(message) }
            }
        }
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
        .task { await service.refresh() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await service.refresh() } }
        }
        .onChange(of: factsEnabled) { _, enabled in
            if enabled && service.authorization == .notDetermined {
                Task { await service.requestPermission() }
            } else {
                service.reschedule()
            }
        }
        .onChange(of: interval) { _, _ in service.reschedule() }
    }
}
