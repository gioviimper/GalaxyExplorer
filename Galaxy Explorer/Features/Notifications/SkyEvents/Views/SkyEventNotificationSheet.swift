import SwiftUI

struct SkyEventNotificationSheet: View {
    let event: SkyEvent
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            SkyEventDetailView(event: event)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }
}
