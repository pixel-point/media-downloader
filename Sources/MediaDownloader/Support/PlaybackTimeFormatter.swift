import Foundation

enum PlaybackTimeFormatter {
    static func string(for seconds: Double, includeFractionWhenNeeded: Bool = true) -> String {
        guard seconds.isFinite, seconds >= 0 else {
            return "00:00"
        }

        let showFraction = includeFractionWhenNeeded && abs(seconds.rounded() - seconds) >= 0.05
        let scale = showFraction ? 10.0 : 1.0
        let roundedUnits = Int((seconds * scale).rounded())

        if showFraction {
            let totalSeconds = roundedUnits / 10
            let tenths = roundedUnits % 10
            let hours = totalSeconds / 3_600
            let minutes = (totalSeconds / 60) % 60
            let remainingSeconds = totalSeconds % 60

            if hours > 0 {
                return String(format: "%d:%02d:%02d.%d", hours, minutes, remainingSeconds, tenths)
            }

            return String(format: "%02d:%02d.%d", minutes, remainingSeconds, tenths)
        }

        let hours = roundedUnits / 3_600
        let minutes = (roundedUnits / 60) % 60
        let remainingSeconds = roundedUnits % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, remainingSeconds)
        }

        return String(format: "%02d:%02d", minutes, remainingSeconds)
    }
}
