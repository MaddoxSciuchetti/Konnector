import SwiftUI

enum TraitScore {
    static let minValue = 0
    static let maxValue = 10

    /// 12 o'clock on the dial.
    private static let topAngle = -Double.pi / 2

    static func clamped(_ value: Int) -> Int {
        min(max(value, minValue), maxValue)
    }

    static func progress(for value: Int) -> Double {
        Double(clamped(value)) / Double(maxValue)
    }

    static func progress(for score: Double) -> Double {
        min(max(score / Double(maxValue), 0), 1)
    }

    static func color(for value: Int) -> Color {
        K.Color.blend(from: K.Color.secondary, to: K.Color.success, amount: progress(for: value))
    }

    static func formatted(_ score: Double) -> String {
        score.formatted(.number.precision(.fractionLength(1)))
    }

    /// Full-ring arc: starts at 12 o'clock and grows clockwise; 10 fills the whole ring.
    static func arcAngles(forProgress progress: Double) -> (start: Double, end: Double) {
        let clamped = min(max(progress, 0), 1)
        let start = topAngle
        let end = topAngle + clamped * 2 * Double.pi
        return (start, end)
    }

    static func arcAngles(forScore score: Double) -> (start: Double, end: Double) {
        arcAngles(forProgress: progress(for: score))
    }

    static func arcEndAngle(for value: Int) -> Double {
        arcAngles(forProgress: progress(for: value)).end
    }

    static func arcEndAngle(forScore score: Double) -> Double {
        arcAngles(forProgress: progress(for: score)).end
    }

    static func value(for angle: Double) -> Int {
        // Clockwise distance from 12 o'clock, normalized to 0…2π.
        var fromTop = angle - topAngle
        while fromTop < 0 { fromTop += 2 * .pi }
        while fromTop >= 2 * .pi { fromTop -= 2 * .pi }

        let progress = fromTop / (2 * .pi)
        return min(max(Int((progress * Double(maxValue)).rounded()), minValue), maxValue)
    }
}

/// Circular score ring with a white dot drawn on the measured stroke centerline.
private struct ScoreProgressRing: View {
    let progress: Double
    let color: Color
    let lineWidth: CGFloat
    var trackColor: Color = Color(.systemGray5)
    var endCapScale: CGFloat = 1

    private var clampedProgress: Double {
        min(max(progress, 0), 1)
    }

    private var arcAngles: (start: Double, end: Double) {
        TraitScore.arcAngles(forProgress: clampedProgress)
    }

    private var startAngle: Double {
        arcAngles.start
    }

    private var endAngle: Double {
        arcAngles.end
    }

    private var hasArcLength: Bool {
        clampedProgress > 0.001
    }

    private var dotDiameter: CGFloat {
        lineWidth * endCapScale
    }

    var body: some View {
        Canvas { context, size in
            let metrics = RingMetrics(size: size, lineWidth: lineWidth)

            var trackPath = Path()
            trackPath.addEllipse(in: metrics.strokeRect)
            context.stroke(
                trackPath,
                with: .color(trackColor.opacity(0.9)),
                style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
            )

            if hasArcLength {
                var progressPath = Path()
                // In SwiftUI's flipped coordinate space, `clockwise: false` sweeps in the
                // direction of increasing angle, which reads as clockwise on screen.
                progressPath.addArc(
                    center: metrics.center,
                    radius: metrics.radius,
                    startAngle: .radians(startAngle),
                    endAngle: .radians(endAngle),
                    clockwise: false
                )
                context.stroke(
                    progressPath,
                    with: .color(color),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .butt)
                )
            }

            if showsIndicatorDot {
                drawIndicatorDot(in: &context, metrics: metrics)
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .animation(.smooth(duration: 0.35), value: clampedProgress)
        .animation(.smooth(duration: 0.35), value: endAngle)
    }

    private func drawIndicatorDot(in context: inout GraphicsContext, metrics: RingMetrics) {
        let dotCenter = metrics.point(on: endAngle)
        // Keep fill + stroke inside the ring thickness so the border never
        // spills past the green bar or the outer track circle.
        let strokeWidth = min(1.25, max(0.6, lineWidth * 0.28))
        let outerDiameter = min(dotDiameter, max(0, lineWidth - strokeWidth))
        let strokeDiameter = max(0, outerDiameter - strokeWidth)
        let fillDiameter = max(0, strokeDiameter - strokeWidth)

        let fillRect = CGRect(
            x: dotCenter.x - fillDiameter / 2,
            y: dotCenter.y - fillDiameter / 2,
            width: fillDiameter,
            height: fillDiameter
        )
        let strokeRect = CGRect(
            x: dotCenter.x - strokeDiameter / 2,
            y: dotCenter.y - strokeDiameter / 2,
            width: strokeDiameter,
            height: strokeDiameter
        )
        var fillPath = Path(ellipseIn: fillRect)
        var strokePath = Path(ellipseIn: strokeRect)
        context.fill(fillPath, with: .color(color))
        context.fill(fillPath, with: .color(.white.opacity(0.82)))
        context.stroke(
            strokePath,
            with: .color(color),
            lineWidth: strokeWidth
        )
    }

    private var showsIndicatorDot: Bool {
        clampedProgress > 0.001 && clampedProgress < 0.999
    }
}

/// Measured ring layout — SwiftUI equivalent of reading element bounds via a ref.
private struct RingMetrics {
    let center: CGPoint
    let radius: CGFloat
    let strokeRect: CGRect

    init(size: CGSize, lineWidth: CGFloat) {
        let side = min(size.width, size.height)
        let originX = (size.width - side) / 2 + lineWidth / 2
        let originY = (size.height - side) / 2 + lineWidth / 2
        let diameter = side - lineWidth

        strokeRect = CGRect(x: originX, y: originY, width: diameter, height: diameter)
        center = CGPoint(x: strokeRect.midX, y: strokeRect.midY)
        radius = diameter / 2
    }

    func point(on angle: Double) -> CGPoint {
        CGPoint(
            x: center.x + radius * cos(angle),
            y: center.y + radius * sin(angle)
        )
    }
}

struct TraitRatingSlider: View {
    let title: String
    @Binding var value: Int
    var dialSize: CGFloat = 112

    private var ringWidth: CGFloat {
        max(8, min(14, dialSize * 0.09))
    }

    private var progress: Double {
        TraitScore.progress(for: value)
    }

    private var valueFontSize: CGFloat {
        dialSize * 0.25
    }

    var body: some View {
        VStack(spacing: K.Spacing.md) {
            Text(title)
                .font(dialSize >= 130 ? .title3.weight(.semibold) : .headline)

            dial
                .frame(width: dialSize, height: dialSize)
                .contentShape(Circle())
                // Gesture must live on the dial itself — a Color.clear `.background`
                // is not hit-tested, so drags never reached the recognizer.
                // highPriorityGesture also wins over the parent ScrollView's pan.
                .highPriorityGesture(dialDragGesture)
                .accessibilityValue("\(value) out of \(TraitScore.maxValue)")
                .accessibilityHint("Drag clockwise around the circle to increase the rating.")
                .accessibilityAdjustableAction { direction in
                    switch direction {
                    case .increment:
                        value = TraitScore.clamped(value + 1)
                    case .decrement:
                        value = TraitScore.clamped(value - 1)
                    @unknown default:
                        break
                    }
                }
        }
    }

    private var dial: some View {
        ZStack {
            ScoreProgressRing(
                progress: progress,
                color: TraitScore.color(for: value),
                lineWidth: ringWidth,
                endCapScale: 1
            )

            Circle()
                .fill(TraitScore.color(for: value).opacity(0.1))
                .padding(ringWidth + 8)

            Text("\(value)")
                .font(.system(size: valueFontSize, weight: .bold, design: .rounded))
                .foregroundStyle(TraitScore.color(for: value))
                .monospacedDigit()
                .contentTransition(.numericText())
                .animation(.smooth, value: value)
        }
    }

    private var dialDragGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { gesture in
                value = rating(
                    at: gesture.location,
                    in: CGSize(width: dialSize, height: dialSize)
                )
            }
    }

    private func rating(at location: CGPoint, in size: CGSize) -> Int {
        let metrics = RingMetrics(size: size, lineWidth: ringWidth)
        let angle = atan2(location.y - metrics.center.y, location.x - metrics.center.x)
        return TraitScore.value(for: angle)
    }
}

struct ContactScoreProgressBar: View {
    let score: Double

    private var progress: Double {
        TraitScore.progress(for: score)
    }

    private var scoreColor: Color {
        TraitScore.color(for: Int(score.rounded()))
    }

    var body: some View {
        ProgressView(value: progress) {
            Text("Score")
                .font(.caption)
        } currentValueLabel: {
            Text(TraitScore.formatted(score))
                .font(.caption.weight(.semibold))
                .monospacedDigit()
        }
        .tint(scoreColor)
        .foregroundStyle(.secondary)
        .accessibilityLabel("Overall score \(TraitScore.formatted(score)) out of 10")
    }
}

struct ContactScoreBadge: View {
    let score: Double
    var size: CGFloat = K.Size.ScoreBadge.regular

    private var displayValue: Int {
        Int(score.rounded())
    }

    private var progress: Double {
        TraitScore.progress(for: score)
    }

    private var ringWidth: CGFloat {
        size <= K.Size.ScoreBadge.compact ? 2.5 : 3
    }

    var body: some View {
        ZStack {
            ScoreProgressRing(
                progress: progress,
                color: TraitScore.color(for: displayValue),
                lineWidth: ringWidth,
                endCapScale: 1
            )

            Text(TraitScore.formatted(score))
                .font(size <= K.Size.ScoreBadge.compact ? .system(size: 9, weight: .bold) : .caption2.weight(.bold))
                .foregroundStyle(TraitScore.color(for: displayValue))
                .monospacedDigit()
        }
        .frame(width: size, height: size)
        .accessibilityLabel("Overall score \(TraitScore.formatted(score)) out of 10")
    }
}

struct TraitScoreCircle: View {
    let title: String
    let value: Double
    let size: CGFloat

    private var ringWidth: CGFloat {
        max(6, min(10, size * 0.12))
    }

    private var displayValue: Int {
        Int(value.rounded())
    }

    private var progress: Double {
        TraitScore.progress(for: value)
    }

    private var scoreColor: Color {
        TraitScore.color(for: displayValue)
    }

    private var titleFont: Font {
        size < 90 ? .caption.weight(.semibold) : .subheadline.weight(.semibold)
    }

    var body: some View {
        VStack(spacing: size < 90 ? K.Spacing.sm : 10) {
            Text(title)
                .font(titleFont)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            ZStack {
                ScoreProgressRing(
                    progress: progress,
                    color: scoreColor,
                    lineWidth: ringWidth,
                    endCapScale: 1
                )

                Circle()
                    .fill(scoreColor.opacity(0.1))
                    .padding(ringWidth + max(6, size * 0.12))

                VStack(spacing: 2) {
                    Text(TraitScore.formatted(value))
                        .font(.system(size: size * 0.22, weight: .bold, design: .rounded))
                        .foregroundStyle(scoreColor)
                        .monospacedDigit()
                        .contentTransition(.numericText())
                        .animation(.smooth, value: value)

                    Text("of 10")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            .frame(width: size, height: size)
        }
    }
}
