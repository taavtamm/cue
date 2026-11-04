import CueUI
import SwiftUI

/// Timer and pace, where the show is, the wall clock, and show controls.
struct PresenterHeader: View {
    let model: PresenterModel

    var body: some View {
        HStack(spacing: 18) {
            TimelineView(.periodic(from: .now, by: 0.5)) { _ in
                let elapsed = model.controller.elapsed
                ElapsedTimer(elapsed: elapsed, target: model.targetDuration, pace: model.pace(at: elapsed).text)
            }
            .fixedSize()
            .layoutPriority(2)
            PositionCounter(
                slide: model.position.slide, slideCount: model.slideCount,
                build: model.position.build, buildCount: model.buildCount
            )
            .fixedSize()
            .padding(.leading, 20)
            Spacer(minLength: 12)
            TimelineView(.everyMinute) { context in
                Text(context.date, format: .dateTime.hour().minute())
                    .font(.system(size: 15, weight: .medium).monospacedDigit())
                    .foregroundStyle(Color.white.opacity(0.8))
                    .padding(.trailing, 10)
            }
            Button(action: model.actions.openDisplays) {
                Label(audienceText, systemImage: "rectangle.on.rectangle").lineLimit(1)
            }
            .buttonStyle(.cue())
            Button(action: model.actions.toggleBlack) {
                HStack(spacing: 4) {
                    Text(model.controller.isBlack ? "Show slide" : "Black screen")
                    KeyHint("B")
                }
            }
            .buttonStyle(.cue())
            Button(model.controller.timer.isRunning ? "Pause timer" : "Resume timer", action: model.actions.toggleTimer)
                .buttonStyle(.cue())
            Button("End show", action: model.actions.end).buttonStyle(.cue(.destructive))
        }
        .frame(height: 56)
    }

    private var audienceText: String {
        model.stageName.map { "Audience on \($0)" } ?? "Choose audience screen"
    }
}
