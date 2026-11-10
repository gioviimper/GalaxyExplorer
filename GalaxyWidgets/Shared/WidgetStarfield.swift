import SwiftUI

struct WidgetStarfield: View {
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color(red: 0.015, green: 0.02, blue: 0.035)
                ForEach(0..<28, id: \.self) { index in
                    Circle()
                        .fill(.white.opacity(index.isMultiple(of: 5) ? 0.65 : 0.22))
                        .frame(
                            width: index.isMultiple(of: 5) ? 1.5 : 0.8,
                            height: index.isMultiple(of: 5) ? 1.5 : 0.8
                        )
                        .position(
                            x: CGFloat((index * 67 + 19) % 101) / 100 * geometry.size.width,
                            y: CGFloat((index * 43 + 31) % 97) / 96 * geometry.size.height)
                }
            }
        }
        .accessibilityHidden(true)
    }
}
