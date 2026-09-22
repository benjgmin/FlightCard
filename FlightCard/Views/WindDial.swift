import SwiftUI

/// North-up (true) compass rose with each runway drawn at its true heading
/// and the wind as an arrow pointing from where it's coming from.
struct WindDial: View {
    let wind: Wind
    /// One entry per runway end, parallels already grouped ("07L / 07R").
    let runwayEnds: [Runway.End]
    let favoredHeading: Int?

    var body: some View {
        Canvas { context, size in
            let side = min(size.width, size.height)
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            // Leave room outside the rose for the wind pointer.
            let radius = side / 2 - 26
            drawRose(context, center: center, radius: radius)
            drawRunways(context, center: center, radius: radius)
            drawWind(context, center: center, radius: radius)
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityElement()
        .accessibilityLabel(accessibilityText)
    }

    // MARK: Geometry

    /// Point at a compass heading (0 = up, clockwise) and distance from center.
    private func point(_ center: CGPoint, _ heading: Double, _ distance: CGFloat) -> CGPoint {
        let rad = heading * .pi / 180
        return CGPoint(
            x: center.x + distance * CGFloat(sin(rad)),
            y: center.y - distance * CGFloat(cos(rad))
        )
    }

    // MARK: Rose

    private func drawRose(_ context: GraphicsContext, center: CGPoint, radius: CGFloat) {
        let ring = Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius,
                                          width: radius * 2, height: radius * 2))
        context.fill(ring, with: .color(Theme.bezel.opacity(0.6)))
        context.stroke(ring, with: .color(Theme.hairline), lineWidth: 1)

        for degrees in stride(from: 0, to: 360, by: 5) {
            let major = degrees % 30 == 0
            let mid = degrees % 10 == 0
            let length: CGFloat = major ? 12 : (mid ? 8 : 4)
            var tick = Path()
            tick.move(to: point(center, Double(degrees), radius - 2))
            tick.addLine(to: point(center, Double(degrees), radius - 2 - length))
            let color = major ? Theme.ink.opacity(0.85) : Theme.dim.opacity(mid ? 0.7 : 0.35)
            context.stroke(tick, with: .color(color), lineWidth: major ? 2 : 1)
        }

        // HSI-style labels: N, 3, 6, E, 12, 15, S...
        for degrees in stride(from: 0, to: 360, by: 30) {
            let cardinal = degrees % 90 == 0
            let label: String = switch degrees {
            case 0: "N"
            case 90: "E"
            case 180: "S"
            case 270: "W"
            default: "\(degrees / 10)"
            }
            let text = Text(label)
                .font(.system(size: 13, weight: cardinal ? .bold : .medium))
                .foregroundStyle(cardinal ? Theme.ink : Theme.dim)
            context.draw(text, at: point(center, Double(degrees), radius - 28))
        }
    }

    // MARK: Runways

    private func drawRunways(_ context: GraphicsContext, center: CGPoint, radius: CGFloat) {
        let halfLength = radius * 0.36
        let halfWidth: CGFloat = 8
        let favoredAxis = favoredHeading.map { $0 % 180 }
        let axes = Set(runwayEnds.map { $0.trueHeading % 180 })

        // Draw the favored strip last so it sits on top.
        let ordered = axes.filter { $0 != favoredAxis }.sorted() + axes.filter { $0 == favoredAxis }

        for axis in ordered {
            let isFavored = axis == favoredAxis
            let rad = Double(axis) * .pi / 180
            let ux = CGFloat(sin(rad)), uy = CGFloat(-cos(rad))   // along the runway
            let px = CGFloat(cos(rad)), py = CGFloat(sin(rad))    // across it

            var strip = Path()
            strip.move(to: CGPoint(x: center.x + ux * halfLength + px * halfWidth,
                                   y: center.y + uy * halfLength + py * halfWidth))
            strip.addLine(to: CGPoint(x: center.x + ux * halfLength - px * halfWidth,
                                      y: center.y + uy * halfLength - py * halfWidth))
            strip.addLine(to: CGPoint(x: center.x - ux * halfLength - px * halfWidth,
                                      y: center.y - uy * halfLength - py * halfWidth))
            strip.addLine(to: CGPoint(x: center.x - ux * halfLength + px * halfWidth,
                                      y: center.y - uy * halfLength + py * halfWidth))
            strip.closeSubpath()
            context.fill(strip, with: .color(isFavored ? Theme.ink : Theme.dim.opacity(0.4)))

            if isFavored {
                var centerline = Path()
                centerline.move(to: CGPoint(x: center.x + ux * (halfLength - 8), y: center.y + uy * (halfLength - 8)))
                centerline.addLine(to: CGPoint(x: center.x - ux * (halfLength - 8), y: center.y - uy * (halfLength - 8)))
                context.stroke(centerline, with: .color(Theme.panel),
                               style: StrokeStyle(lineWidth: 1.5, dash: [6, 5]))
            }
        }

        // Runway numbers sit at the approach end, like out the windshield:
        // landing 07, you come in from the southwest, so "07" sits near 25.
        // Busy airports (BOS, ATL) have labels that would pile up, so each one
        // measures itself and moves along its approach line, then sideways,
        // until it's clear of the rose numbers and every label placed before it.
        var taken: [CGRect] = stride(from: 0, to: 360, by: 30).map { degrees in
            let p = point(center, Double(degrees), radius - 28)
            return CGRect(x: p.x - 12, y: p.y - 10, width: 24, height: 20)
        }

        // Favored end first, so it always gets the cleanest spot.
        let labelOrder = runwayEnds.filter { $0.trueHeading == favoredHeading }
            + runwayEnds.filter { $0.trueHeading != favoredHeading }

        for end in labelOrder {
            let isFavoredEnd = end.trueHeading == favoredHeading
            let text = Text(compactLabel(end.designator))
                .font(.system(size: 12, weight: .bold).width(.condensed))
                .foregroundStyle(isFavoredEnd ? Theme.cyan : Theme.dim)
            let resolved = context.resolve(text)
            let size = resolved.measure(in: CGSize(width: 200, height: 40))

            let rad = Double(end.trueHeading + 180) * .pi / 180
            let ux = CGFloat(sin(rad)), uy = CGFloat(-cos(rad))   // along the approach line
            let px = CGFloat(cos(rad)), py = CGFloat(sin(rad))    // sideways

            // How far the label reaches along each axis, so it clears the strip end.
            let alongExtent = abs(ux) * size.width / 2 + abs(uy) * size.height / 2
            let sideStep = abs(px) * size.width + abs(py) * size.height + 2
            let base = halfLength + alongExtent + 4

            func rect(along: CGFloat, side: CGFloat) -> CGRect {
                let c = CGPoint(x: center.x + ux * along + px * side,
                                y: center.y + uy * along + py * side)
                return CGRect(x: c.x - size.width / 2, y: c.y - size.height / 2,
                              width: size.width, height: size.height)
            }

            var chosen = rect(along: base, side: 0)
            search: for extra: CGFloat in [0, 10, 20] {
                for side: CGFloat in [0, 1, -1, 2, -2] {
                    let candidate = rect(along: base + extra, side: side * sideStep)
                    if !taken.contains(where: { $0.intersects(candidate) }) {
                        chosen = candidate
                        break search
                    }
                }
            }
            taken.append(chosen)
            context.draw(resolved, at: CGPoint(x: chosen.midX, y: chosen.midY))
        }
    }

    /// "07L / 07R" -> "07L/07R". Three or more parallels -> "08L–10".
    private func compactLabel(_ designator: String) -> String {
        let parts = designator.components(separatedBy: " / ")
        guard parts.count > 2, let first = parts.first, let last = parts.last else {
            return parts.joined(separator: "/")
        }
        return "\(first)–\(last)"
    }

    // MARK: Wind

    private func drawWind(_ context: GraphicsContext, center: CGPoint, radius: CGFloat) {
        guard !wind.isCalm, case .trueDegrees(let direction) = wind.direction else {
            let text = Text(wind.isCalm ? "Calm" : "Variable")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.cyan)
            context.draw(text, at: CGPoint(x: center.x, y: center.y + radius * 0.68))
            return
        }

        // Pointer sits on the bezel outside the rose, pointing inward like an
        // HSI bug, so it never covers the runways or their numbers.
        let heading = Double(direction)
        let tail = point(center, heading, radius + 22)
        let tip = point(center, heading, radius - 6)

        var shaft = Path()
        shaft.move(to: tail)
        shaft.addLine(to: point(center, heading, radius + 4))
        context.stroke(shaft, with: .color(Theme.cyan), style: StrokeStyle(lineWidth: 3, lineCap: .round))

        let rad = heading * .pi / 180
        let ux = CGFloat(sin(rad)), uy = CGFloat(-cos(rad))   // outward
        let px = CGFloat(cos(rad)), py = CGFloat(sin(rad))    // sideways
        var head = Path()
        head.move(to: tip)
        head.addLine(to: CGPoint(x: tip.x + ux * 14 + px * 8, y: tip.y + uy * 14 + py * 8))
        head.addLine(to: CGPoint(x: tip.x + ux * 14 - px * 8, y: tip.y + uy * 14 - py * 8))
        head.closeSubpath()
        context.fill(head, with: .color(Theme.cyan))

        // Faint line across the rose shows the wind's path without hiding anything.
        var track = Path()
        track.move(to: point(center, heading, radius - 8))
        track.addLine(to: point(center, heading + 180, radius - 8))
        context.stroke(track, with: .color(Theme.cyan.opacity(0.25)),
                       style: StrokeStyle(lineWidth: 1, dash: [3, 5]))
    }

    private var accessibilityText: String {
        if wind.isCalm { return "Wind calm" }
        switch wind.direction {
        case .trueDegrees(let degrees):
            let gust = wind.gustKt.map { ", gusting \($0)" } ?? ""
            return "Wind from \(degrees) degrees true at \(wind.speedKt) knots\(gust)"
        case .variable:
            return "Wind variable at \(wind.speedKt) knots"
        }
    }
}
