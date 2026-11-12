import UIKit

extension Planet3DView.Coordinator {
    // Apply the selected fill synchronously before the information sheet covers the card.
    func updateSelectedCard(id: String?) {
        for card in cards {
            guard cardContents.indices.contains(card.tag) else { continue }
            let selected = cardContents[card.tag].id == id
            guard card.isSelected != selected else { continue }
            card.isSelected = selected
            card.setNeedsUpdateConfiguration()
            card.updateConfiguration()
        }
    }
}
