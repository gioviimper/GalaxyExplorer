import CoreHaptics
import CoreMotion
import SceneKit
import UIKit
import simd

extension Planet3DView {
    // State and lifetime stay here; extensions organize callouts, gestures, motion and haptics.
    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var parent: Planet3DView
        weak var scnView: SCNView?
        weak var cameraNode: SCNNode?
        weak var planetNode: SCNNode?

        // Decorative anchor slots; these are not surveyed landmark coordinates.
        // Keep stable IDs when mapping future NASA content to these slots.
        static let cardCount = 14
        let anchors: [SIMD3<Float>] = (0..<Coordinator.cardCount).map { index in
            let y = 1 - 2 * (Float(index) + 0.5) / Float(Coordinator.cardCount)
            let radius = sqrt(max(0, 1 - y * y))
            let angle = Float(index) * .pi * (3 - sqrt(5))
            return SIMD3<Float>(cos(angle) * radius, y, sin(angle) * radius)
        }
        // NASA API CONTENT GOES HERE: Supply title, summary, and detail fields by
        // stable card ID. Cards intentionally contain no bundled editorial text.
        // Fetch through a content service, cache successful responses for offline use,
        // and update the UI on the main actor without resetting the scene.
        struct CardContent {
            let id: String
            var title: String?
            var summary: String?
            var detail: String?
        }

        // NASA API CONTENT GOES HERE: Map a different response item to each stable ID.
        // Keep these fields nil until real API content is available; do not duplicate
        // one article across every card. Preserve the mapping when the planet rotates.
        let cardContents: [CardContent]

        let lineCanvas = UIView()
        var cards: [UIButton] = []
        var cachedCardWidth: CGFloat = 0
        var cachedCardHeights: [CGFloat] = []
        var lines: [CAShapeLayer] = []
        var visible = Array(repeating: false, count: Coordinator.cardCount)
        var leftSide = Array(repeating: false, count: Coordinator.cardCount)
        var calloutLink: CADisplayLink?
        var lastRequestID: UUID?

        let zoomFeedback = UIImpactFeedbackGenerator(style: .rigid)
        var zoomTravel: Float = 0
        var lastZoomPulse: CFTimeInterval = 0

        let planetImpact = UIImpactFeedbackGenerator(style: .heavy)
        let surfaceFallback = UIImpactFeedbackGenerator(style: .rigid)
        var surfaceEngine: CHHapticEngine?
        var surfacePlayer: CHHapticPatternPlayer?
        var isDraggingSurface = false
        var surfaceTravel: CGFloat = 0
        var lastSurfacePulse: CFTimeInterval = 0

        let motionManager = CMMotionManager()
        let touchFeedback = UIImpactFeedbackGenerator(style: .soft)
        var lastFeedbackTime: CFTimeInterval = 0
        var referenceAttitude: simd_quatf?
        var motionOrientation: UIInterfaceOrientation?
        var parallax = SIMD2<Float>.zero
        var immersionStarted = false

        var displayLink: CADisplayLink?
        var angularVelocity = CGPoint.zero
        var lastFrameTimestamp: CFTimeInterval?

        // CADisplayLink retains its target; a weak proxy avoids a retain cycle.
        final class DisplayLinkProxy: NSObject {
            weak var owner: Coordinator?
            init(owner: Coordinator) { self.owner = owner }
            @objc func callouts(_ link: CADisplayLink) {
                guard let owner else {
                    link.invalidate()
                    return
                }
                owner.layoutCallouts()
            }
            @objc func tick(_ link: CADisplayLink) {
                guard let owner else {
                    link.invalidate()
                    return
                }
                owner.updateInertia(link)
            }
        }

        init(_ parent: Planet3DView) {
            self.parent = parent
            self.lastRequestID = parent.request?.id
            // NASA API CONTENT GOES HERE: Cache by planet ID and card ID so data stays separate.
            self.cardContents = (0..<Coordinator.cardCount).map { index in
                CardContent(
                    id: String(format: "%@-card-%02d", parent.planet.id, index + 1),
                    title: nil, summary: nil, detail: nil)
            }
        }
        deinit {
            surfaceEngine?.stop(completionHandler: nil)
            calloutLink?.invalidate()
            displayLink?.invalidate()
            motionManager.stopDeviceMotionUpdates()
            NotificationCenter.default.removeObserver(self)
        }
    }
}
