import AppIntents
import Observation

/// Shared flag the intent sets so the UI starts recording once the app is in the foreground.
@MainActor
@Observable
final class VoiceCaptureRequest {
    static let shared = VoiceCaptureRequest()
    var isPending = false
    private init() {}
}

/// Opens the app straight into voice recording. Assign it to the Action Button via
/// Settings > Action Button > Shortcut > Summary > "Record a Thought".
struct RecordThoughtIntent: AppIntent {
    static let title: LocalizedStringResource = "Record a Thought"
    static let description = IntentDescription("Opens Summary and starts recording a voice thought.")
    static let openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        VoiceCaptureRequest.shared.isPending = true
        return .result()
    }
}

struct SummaryShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: RecordThoughtIntent(),
            phrases: [
                "Record a thought in \(.applicationName)",
                "Dump a thought in \(.applicationName)",
            ],
            shortTitle: "Record a Thought",
            systemImageName: "mic.fill"
        )
    }
}
