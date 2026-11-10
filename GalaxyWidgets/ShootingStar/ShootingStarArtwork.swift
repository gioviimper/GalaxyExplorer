import SwiftUI

struct ShootingStarArtwork: View {
    var body: some View {
        ZStack(alignment: .trailing) {
            // The tail fades towards the left and travels together with the star.
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [.clear, .primary.opacity(0.75)],
                        startPoint: .leading, endPoint: .trailing)
                )
                .frame(width: 34, height: 2)
                .offset(x: -12)
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [.clear, .primary.opacity(0.35)],
                        startPoint: .leading, endPoint: .trailing)
                )
                .frame(width: 22, height: 1)
                .offset(x: -16, y: 5)
            Image(systemName: "sparkle")
                .resizable()
                .scaledToFit()
                .frame(width: 23, height: 23)
        }
        .frame(width: 54, height: 34)
        .accessibilityHidden(true)
    }
}
