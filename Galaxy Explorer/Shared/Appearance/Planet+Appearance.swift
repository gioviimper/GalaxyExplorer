import UIKit

// I tint the native cards while retaining opaque system surfaces and readable label colors.
extension Planet {
    var cardAccent: UIColor {
        let hex = cardTintHex ?? fallbackColorHex
        return UIColor(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
    }

    var cardSelectedBackground: UIColor {
        cardSurface(tintAmount: 0.78, highContrastAmount: 0.60)
    }

    var cardSelectedForeground: UIColor {
        let background = cardSelectedBackground
        return UIColor { traits in
            let resolved = background.resolvedColor(with: traits)
            var red: CGFloat = 0
            var green: CGFloat = 0
            var blue: CGFloat = 0
            var alpha: CGFloat = 0
            resolved.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
            func linear(_ value: CGFloat) -> CGFloat {
                value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
            }
            let luminance = 0.2126 * linear(red) + 0.7152 * linear(green) + 0.0722 * linear(blue)
            // Choose the text color with the greater contrast against the selected fill.
            return luminance > 0.179 ? .black : .white
        }
    }

    var cardBackground: UIColor {
        cardSurface(tintAmount: 0.34, highContrastAmount: 0.18)
    }

    private func cardSurface(tintAmount: CGFloat, highContrastAmount: CGFloat) -> UIColor {
        let accent = cardAccent
        return UIColor { traits in
            let surface = UIColor.secondarySystemBackground.resolvedColor(with: traits)
            var red: CGFloat = 0
            var green: CGFloat = 0
            var blue: CGFloat = 0
            var alpha: CGFloat = 0
            var tintRed: CGFloat = 0
            var tintGreen: CGFloat = 0
            var tintBlue: CGFloat = 0
            var tintAlpha: CGFloat = 0
            surface.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
            accent.getRed(&tintRed, green: &tintGreen, blue: &tintBlue, alpha: &tintAlpha)
            // High contrast keeps the fill closer to the original system surface.
            let amount: CGFloat = traits.accessibilityContrast == .high ? highContrastAmount : tintAmount
            return UIColor(
                red: red * (1 - amount) + tintRed * amount,
                green: green * (1 - amount) + tintGreen * amount,
                blue: blue * (1 - amount) + tintBlue * amount, alpha: 1)
        }
    }
}
