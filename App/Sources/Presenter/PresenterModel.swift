import CueCore
import Foundation
import Observation
import SwiftUI

/// What the presenter and confidence screens show. Reads the live
/// `ShowController`; buttons call back into the show session.
@MainActor @Observable
final class PresenterModel {
    let controller: ShowController
    let slides: [SlideInfo]
    let canvas: CanvasSize
    var targetDuration: TimeInterval
    /// Notes text size in points, changed with A− / A+.
    var notesSize: CGFloat = 22
    /// Shown in the header and info row, e.g. "LG UltraFine 5K".
    var stageName: String?
    var confidenceName: String?
    var renderingSummary = "Native HTML · offline"
    /// Slides with live web content, reported by the stage.
    var liveSlides: Set<Int> = []
    /// Focus / Do Not Disturb is known to be off. Shown on presenter screens only.
    var showsFocusWarning = false
    /// Rehearsing alone on this Mac: no audience, so audience controls are hidden.
    var isRehearsal = false
    @ObservationIgnored var actions = PresenterActions()

    static let notesSizes: ClosedRange<CGFloat> = 14...44

    init(controller: ShowController, structure: DeckStructure, targetDuration: TimeInterval) {
        self.controller = controller
        slides = structure.slides
        canvas = structure.canvas
        self.targetDuration = targetDuration
    }

    var position: ShowPosition { controller.position }
    var slideCount: Int { slides.count }
    var buildCount: Int { slides.indices.contains(position.slide) ? slides[position.slide].builds.count : 0 }

    var currentNotes: String {
        slides.indices.contains(position.slide) ? slides[position.slide].notes : ""
    }

    func label(of slide: Int) -> String {
        guard slides.indices.contains(slide) else { return "" }
        let label = slides[slide].label
        return label.isEmpty ? "Slide \(slide + 1)" : label
    }

    /// "Next · <label>", "Next build", or "End of show".
    var nextTitle: String {
        if position.build < buildCount { return "Next build" }
        return position.slide + 1 < slideCount ? "Next · \(label(of: position.slide + 1))" : "End of show"
    }

    var hasNext: Bool { !controller.isOnLastState }

    /// The main button's title: what pressing → will do.
    var advanceTitle: String { position.build < buildCount ? "Next build" : "Next slide" }

    func pace(at elapsed: TimeInterval) -> ShowPace {
        let progress = ShowPace.progress(of: position, stateCounts: controller.stateCounts)
        return ShowPace(elapsed: elapsed, target: targetDuration, progress: progress)
    }

    /// The show timer redraws once a second, on the second, and not at all
    /// while it's paused (an hour between ticks; any change redraws anyway).
    static func clockSchedule(running: Bool) -> PeriodicTimelineSchedule {
        .periodic(from: Date(timeIntervalSinceReferenceDate: Date().timeIntervalSinceReferenceDate.rounded(.down)),
                  by: running ? 1 : 3_600)
    }

    func biggerNotes() { notesSize = min(Self.notesSizes.upperBound, notesSize + 3) }
    func smallerNotes() { notesSize = max(Self.notesSizes.lowerBound, notesSize - 3) }
}

/// The presenter's buttons. Set by `ShowSession`.
@MainActor
struct PresenterActions {
    var next: () -> Void = {}
    var previous: () -> Void = {}
    var jump: (Int) -> Void = { _ in }
    var toggleBlack: () -> Void = {}
    var toggleTimer: () -> Void = {}
    var end: () -> Void = {}
    var openDisplays: () -> Void = {}
}
