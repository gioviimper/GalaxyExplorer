import AppIntents

struct LaunchShootingStarIntent: AppIntent {
    static var title: LocalizedStringResource = "Launch Shooting Star"
    static var description = IntentDescription("Send a shooting star across the widget.")
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult {
        UserDefaults.standard.set(ShootingStarState.flight &+ 1, forKey: ShootingStarState.key)
        // WidgetKit reloads the timeline after this interactive intent finishes.
        return .result()
    }
}
