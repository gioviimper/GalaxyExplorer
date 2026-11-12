import SceneKit
import UIKit

// Callouts behavior for the shared planet scene coordinator.
extension Planet3DView.Coordinator {
    func installCallouts() {
        guard cards.isEmpty, let view = scnView else { return }
        lineCanvas.isUserInteractionEnabled = false
        lineCanvas.accessibilityElementsHidden = true
        lineCanvas.backgroundColor = .clear
        view.addSubview(lineCanvas)
        for i in anchors.indices {
            let line = CAShapeLayer()
            line.strokeColor = parent.planet.cardAccent.withAlphaComponent(0.85).cgColor
            line.fillColor = UIColor.clear.cgColor
            line.lineWidth = 1
            line.opacity = 0
            lineCanvas.layer.addSublayer(line)
            lines.append(line)
            let card = UIButton(type: .system)
            var config = UIButton.Configuration.filled()
            // Content updates keep the same surface slot and scene orientation.
            let content = cardContents[i]
            config.title = NASAPlanetContentMapper.clip(content.title ?? "", limit: 48)
            config.subtitle = nil
            card.accessibilityIdentifier = content.id
            card.accessibilityLabel = content.title ?? "Information card \(i + 1)"
            card.accessibilityHint = "Opens information"
            config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attributes in
                var result = attributes
                result.font = UIFont.preferredFont(forTextStyle: .subheadline)
                return result
            }
            config.subtitleTextAttributesTransformer = UIConfigurationTextAttributesTransformer {
                attributes in
                var result = attributes
                result.font = UIFont.preferredFont(forTextStyle: .caption1)
                return result
            }
            config.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12)
            // Empty slots stay blank while their content is loading.
            config.baseForegroundColor = .label
            config.baseBackgroundColor = parent.planet.cardBackground
            config.background.strokeWidth = 0.75
            config.background.strokeColor = parent.planet.cardAccent.withAlphaComponent(0.8)
            config.buttonSize = .large
            config.cornerStyle = .medium
            card.configuration = config
            card.configurationUpdateHandler = { [weak self] button in
                guard let self else { return }
                var configuration = button.configuration ?? .filled()
                let active = button.isSelected || button.isHighlighted
                let fill =
                    active
                    ? self.parent.planet.cardSelectedBackground : self.parent.planet.cardBackground
                configuration.baseBackgroundColor = fill
                configuration.background.backgroundColor = fill
                configuration.baseForegroundColor =
                    active
                    ? self.parent.planet.cardSelectedForeground : .label
                configuration.background.strokeWidth = active ? 2.5 : 0.75
                button.configuration = configuration
            }
            card.titleLabel?.numberOfLines = 2
            card.subtitleLabel?.numberOfLines = 1
            card.tag = i
            card.alpha = 0
            card.isUserInteractionEnabled = false
            card.accessibilityElementsHidden = true
            card.addTarget(self, action: #selector(openCard(_:)), for: .touchUpInside)
            view.addSubview(card)
            cards.append(card)
        }
    }

    @objc func openCard(_ sender: UIButton) {
        guard cardContents.indices.contains(sender.tag) else { return }
        stopInertia()
        pulse(0.55)
        let content = cardContents[sender.tag]
        updateSelectedCard(id: content.id)
        parent.onCardSelected?(
            PlanetInformation(
                id: content.id, planetName: parent.planet.name,
                title: content.title, summary: content.summary, detail: content.detail,
                imageURL: content.imageURL, sourceURL: content.sourceURL, credit: content.credit))
    }

    // TODO(API): Keep all networking and JSON decoding out of this frame callback.
    // For actual landmarks, validate coordinates and texture alignment before
    // replacing the illustrative anchors; general articles have no surface location.
    @objc func layoutCallouts() {
        guard let view = scnView, let planet = planetNode, let camera = cameraNode,
            view.window != nil, view.bounds.width > 0, cards.count == anchors.count
        else { return }
        if !parent.planet.rings.isEmpty {
            PlanetRingDetail.updateVisibility(
                on: planet, camera: camera, motionEnabled: automaticAtmosphereMotionAllowed
            )
            if PlanetAtmosphereStyle.style(for: parent.planet.id) == .none {
                setAtmosphereMotionEnabled(automaticAtmosphereMotionAllowed)
            }
        }
        lineCanvas.frame = view.bounds
        let centerPoint = view.projectPoint(SCNVector3(planet.simdWorldPosition))
        let edge = view.projectPoint(SCNVector3(planet.simdWorldPosition + SIMD3<Float>(1, 0, 0)))
        let radius = abs(CGFloat(edge.x - centerPoint.x))
        let width = view.bounds.width
        let top = view.safeAreaInsets.top + 16
        let bottom = max(top + 80, view.bounds.height - view.safeAreaInsets.bottom - 92)
        let cardWidth = min(158, (width - 56) / 2)
        if cachedCardWidth != cardWidth || cachedCardHeights.count != cards.count {
            cachedCardWidth = cardWidth
            cachedCardHeights = cards.map {
                max(64, $0.sizeThatFits(CGSize(width: cardWidth, height: 1000)).height)
            }
        }
        let cardHeights = cachedCardHeights
        // Choose the most front-facing slots; show at most three at a time.
        // A small score bias keeps existing cards stable during slow rotation.
        let ranked = anchors.indices.compactMap { i -> (Int, Float, Bool)? in
            let world = planet.simdConvertPosition(anchors[i], to: nil)
            let normal = simd_normalize(world - planet.simdWorldPosition)
            let facing = simd_dot(normal, simd_normalize(camera.simdWorldPosition - world))
            let projected = view.projectPoint(SCNVector3(world))
            let point = CGPoint(x: CGFloat(projected.x), y: CGFloat(projected.y))
            guard projected.z > 0, projected.z < 1, view.bounds.contains(point),
                facing > (visible[i] ? 0.04 : 0.12)
            else { return nil }
            return (i, facing + (visible[i] ? 0.08 : 0), point.x < width / 2)
        }.sorted { $0.1 > $1.1 }
        var allowed = Set<Int>()
        var leftCount = 0
        var rightCount = 0
        for item in ranked where allowed.count < 3 {
            if item.2 && leftCount < 2 {
                allowed.insert(item.0)
                leftCount += 1
            }
            if !item.2 && rightCount < 2 {
                allowed.insert(item.0)
                rightCount += 1
            }
        }
        var items: [(Int, CGPoint, Bool)] = []
        for i in anchors.indices {
            let world = planet.simdConvertPosition(simd_normalize(anchors[i]), to: nil)
            let projected = view.projectPoint(SCNVector3(world))
            let point = CGPoint(x: CGFloat(projected.x), y: CGFloat(projected.y))
            let showing = allowed.contains(i)
            if showing != visible[i] {
                visible[i] = showing
                cards[i].isUserInteractionEnabled = showing
                cards[i].accessibilityElementsHidden = !showing
                UIView.animate(withDuration: UIAccessibility.isReduceMotionEnabled ? 0 : 0.18) {
                    self.cards[i].alpha = showing ? 1 : 0
                }
            }
            if showing {
                if point.x < width / 2 - 20 { leftSide[i] = true }
                if point.x > width / 2 + 20 { leftSide[i] = false }
                items.append((i, point, leftSide[i]))
            } else {
                CATransaction.begin()
                CATransaction.setDisableActions(true)
                lines[i].opacity = 0
                CATransaction.commit()
            }
        }
        for left in [true, false] {
            let group = items.filter { $0.2 == left }.sorted { $0.1.y < $1.1.y }
            let largest = group.map { cardHeights[$0.0] }.max() ?? 64
            let gap = max(largest + 12, 80)
            var previous = top - gap
            for (rank, item) in group.enumerated() {
                let (i, point, _) = item
                let remaining = CGFloat(group.count - rank - 1)
                let outerY =
                    point.y < CGFloat(centerPoint.y)
                    ? CGFloat(centerPoint.y) - radius - 100 : CGFloat(centerPoint.y) + radius + 24
                let y = max(previous + gap, min(bottom - remaining * gap, max(top, outerY)))
                previous = y
                let frame = CGRect(
                    x: left ? 20 : width - cardWidth - 20,
                    y: min(y, view.bounds.height - view.safeAreaInsets.bottom - cardHeights[i] - 16),
                    width: cardWidth, height: cardHeights[i])
                if cards[i].frame != frame { cards[i].frame = frame }
                let path = UIBezierPath()
                path.move(to: point)
                path.addLine(to: CGPoint(x: left ? frame.maxX : frame.minX, y: frame.midY))
                path.move(to: CGPoint(x: point.x + 3, y: point.y))
                path.addArc(withCenter: point, radius: 3, startAngle: 0, endAngle: .pi * 2, clockwise: true)
                CATransaction.begin()
                CATransaction.setDisableActions(true)
                lines[i].strokeColor =
                    parent.planet.cardAccent
                    .resolvedColor(with: view.traitCollection).withAlphaComponent(0.85).cgColor
                lines[i].path = path.cgPath
                lines[i].opacity = 1
                CATransaction.commit()
            }
        }
    }

    @objc func refreshCalloutAppearance() {
        cachedCardHeights.removeAll()
        for card in cards { card.setNeedsUpdateConfiguration() }
        layoutCallouts()
    }
}
