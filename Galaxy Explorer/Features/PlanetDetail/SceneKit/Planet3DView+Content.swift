import UIKit

// Apply metadata without replacing the SceneKit view, orientation or sensor state.
extension Planet3DView.Coordinator {
    func updateContent(_ items: [PlanetCardContent]) {
        var changed = false
        for item in items {
            guard let index = cardContents.firstIndex(where: { $0.id == item.id }),
                cardContents[index] != item
            else { continue }
            cardContents[index] = item
            changed = true
            guard cards.indices.contains(index) else { continue }
            let card = cards[index]
            var configuration = card.configuration ?? .filled()
            configuration.title = NASAPlanetContentMapper.clip(item.title ?? "", limit: 48)
            // Keep orbiting previews compact; the sheet holds the full description.
            configuration.subtitle = nil
            card.configuration = configuration
            card.titleLabel?.numberOfLines = 2
            card.titleLabel?.lineBreakMode = .byTruncatingTail
            card.accessibilityLabel = item.title ?? "Information card \(index + 1)"
            card.accessibilityHint =
                item.title == nil ? "Information is not available yet" : "Opens NASA image and description"
        }
        if changed {
            cachedCardHeights.removeAll()
            layoutCallouts()
        }
    }
}
