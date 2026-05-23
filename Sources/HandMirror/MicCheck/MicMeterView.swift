import SwiftUI

/// Eight-bar VU-style meter docked to the bottom of the mirror. Bars light up
/// from left (green) to right (red) as the input level rises.
struct MicMeterView: View {
    @ObservedObject var monitor: MicMonitor

    private let barCount = 8

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<barCount, id: \.self) { i in
                Capsule()
                    .fill(color(for: i))
                    .frame(width: 3, height: height(for: i))
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.black.opacity(0.55), in: Capsule())
        .animation(.linear(duration: 0.05), value: monitor.level)
    }

    private func threshold(for index: Int) -> Float {
        Float(index + 1) / Float(barCount)
    }

    private func height(for index: Int) -> CGFloat {
        let base: CGFloat = 6 + CGFloat(index) * 1.5
        return monitor.level >= threshold(for: index) ? base : base * 0.4
    }

    private func color(for index: Int) -> Color {
        guard monitor.level >= threshold(for: index) else {
            return .white.opacity(0.25)
        }
        if index < 5 { return .green }
        if index < 7 { return .yellow }
        return .red
    }
}
