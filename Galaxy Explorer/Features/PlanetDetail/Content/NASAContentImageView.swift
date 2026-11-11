import SwiftUI

// Preview images load only when the user opens the native information sheet.
struct NASAContentImageView: View {
    let url: URL
    var body: some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case .success(let image):
                image.resizable().scaledToFit().frame(maxHeight: 280)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            case .failure:
                Label("Image unavailable", systemImage: "photo")
                    .foregroundStyle(.secondary).frame(maxWidth: .infinity, minHeight: 80)
            default:
                ProgressView("Loading NASA image…")
                    .frame(maxWidth: .infinity, minHeight: 160)
            }
        }
        .accessibilityHidden(true)
    }
}
