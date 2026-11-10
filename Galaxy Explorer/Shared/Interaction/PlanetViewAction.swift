import Foundation

// Native menu actions offer alternatives to dragging and pinching.
enum PlanetViewAction: String, CaseIterable, Identifiable {
    case zoomIn, zoomOut, rotateLeft, rotateRight, rotateUp, rotateDown, reset
    var id: String { rawValue }

    var title: String {
        switch self {
        case .zoomIn: return "Zoom in"
        case .zoomOut: return "Zoom out"
        case .rotateLeft: return "Rotate left"
        case .rotateRight: return "Rotate right"
        case .rotateUp: return "Rotate up"
        case .rotateDown: return "Rotate down"
        case .reset: return "Reset view"
        }
    }

    var symbol: String {
        switch self {
        case .zoomIn: return "plus.magnifyingglass"
        case .zoomOut: return "minus.magnifyingglass"
        case .rotateLeft: return "arrow.left"
        case .rotateRight: return "arrow.right"
        case .rotateUp: return "arrow.up"
        case .rotateDown: return "arrow.down"
        case .reset: return "arrow.counterclockwise"
        }
    }
}

struct PlanetViewRequest {
    let id = UUID()
    let action: PlanetViewAction
}
