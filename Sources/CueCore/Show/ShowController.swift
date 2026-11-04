import Foundation
import Observation

/// The single source of truth while presenting: where the show is, whether
/// the screen is blanked, and the timer. Every surface renders from
/// `position`; nothing else moves slides.
@MainActor @Observable
public final class ShowController {
    public private(set) var position: ShowPosition = .start
    public private(set) var isBlack = false
    public private(set) var isWhite = false
    /// Set when the presenter asks to end (Esc). The app closes the show.
    public private(set) var endRequested = false
    /// Digits typed so far for "number then Return".
    public private(set) var typedNumber: Int?
    public private(set) var timer = ShowTimer()

    /// States per slide: 1 + number of builds.
    public private(set) var stateCounts: [Int]
    private let clock: ShowClock

    public init(stateCounts: [Int], clock: ShowClock = .system) {
        self.stateCounts = stateCounts.map { max(1, $0) }
        self.clock = clock
    }

    public convenience init(structure: DeckStructure, clock: ShowClock = .system) {
        self.init(stateCounts: structure.slides.map(\.stateCount), clock: clock)
    }

    public var slideCount: Int { stateCounts.count }
    public var isOnLastState: Bool {
        position.slide == slideCount - 1 && position.build == finalBuild(of: position.slide)
    }
    public var elapsed: TimeInterval { timer.elapsed(at: clock.now()) }

    public func finalBuild(of slide: Int) -> Int {
        stateCounts.indices.contains(slide) ? stateCounts[slide] - 1 : 0
    }

    // MARK: Keys

    public func handle(_ key: ShowKey) {
        if case .digit(let digit) = key {
            typedNumber = min((typedNumber ?? 0) * 10 + digit, 9_999)
            return
        }
        let typed = typedNumber
        typedNumber = nil
        switch key {
        case .next: next()
        case .previous: previous()
        case .first: jump(toSlide: 0)
        case .last: jump(toSlide: slideCount - 1)
        case .toggleBlack: setBlank(black: !isBlack, white: false)
        case .toggleWhite: setBlank(black: false, white: !isWhite)
        case .confirm: jumpToTyped(typed)
        case .endShow: endRequested = true
        case .digit: break
        }
    }

    private func jumpToTyped(_ number: Int?) {
        guard let number, number > 0 else { return }
        jump(toSlide: number - 1)
    }

    // MARK: Navigation

    /// Next build, else the next slide. Stays put at the end of the show.
    public func next() {
        startTimerIfNeeded()
        clearBlank()
        guard slideCount > 0 else { return }
        if position.build < finalBuild(of: position.slide) {
            position.build += 1
        } else if position.slide < slideCount - 1 {
            position = ShowPosition(slide: position.slide + 1)
        }
    }

    /// Previous build, else the previous slide in its finished state.
    public func previous() {
        clearBlank()
        if position.build > 0 {
            position.build -= 1
        } else if position.slide > 0 {
            let slide = position.slide - 1
            position = ShowPosition(slide: slide, build: finalBuild(of: slide))
        }
    }

    public func jump(toSlide slide: Int, build: Int = 0) {
        clearBlank()
        guard slideCount > 0 else { return }
        let clamped = min(max(0, slide), slideCount - 1)
        position = ShowPosition(slide: clamped, build: min(max(0, build), finalBuild(of: clamped)))
    }

    /// In passthrough mode the deck's own script moves; Cue follows it.
    public func follow(_ reported: ShowPosition) {
        guard slideCount > 0 else { return }
        let slide = min(max(0, reported.slide), slideCount - 1)
        position = ShowPosition(slide: slide, build: min(max(0, reported.build), finalBuild(of: slide)))
    }

    /// The deck changed (an edit added or removed slides). Keep the position valid.
    public func update(stateCounts: [Int]) {
        self.stateCounts = stateCounts.map { max(1, $0) }
        follow(position)
    }

    // MARK: Blank screen and timer

    public func setBlank(black: Bool, white: Bool) {
        isBlack = black
        isWhite = white && !black
    }

    private func clearBlank() { setBlank(black: false, white: false) }

    public func startTimerIfNeeded() { timer.start(at: clock.now()) }
    public func pauseTimer() { timer.pause(at: clock.now()) }
    public func toggleTimer() {
        if timer.isRunning { pauseTimer() } else { startTimerIfNeeded() }
    }
    public func resetTimer() { timer.reset() }
}
