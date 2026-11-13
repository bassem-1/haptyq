import SwiftUI
import HaptyqKit

/// The signature control: five cells, cell i sets Feel(level: i).
struct SignalBar: View {
    @Binding var feel: Feel
    let label: String

    var body: some View {
        HStack(spacing: 8) {
            HStack(spacing: 0) {
                ForEach(0..<5, id: \.self) { i in
                    cell(i)
                        .frame(width: 13, height: Theme.row, alignment: .leading)
                        .contentShape(Rectangle())
                        .onTapGesture { feel = Feel(level: i) }
                }
            }
            .padding(.trailing, -3)
            Text(feel.title)
                .font(Theme.font(11))
                .foregroundColor(Theme.fg2)
                .frame(width: 48, alignment: .leading)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue(feel.title)
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: feel = Feel(level: feel.level + 1)
            case .decrement: feel = Feel(level: feel.level - 1)
            @unknown default: break
            }
        }
    }

    @ViewBuilder private func cell(_ i: Int) -> some View {
        if i == 0 {
            RoundedRectangle(cornerRadius: 1)
                .fill(feel == .off ? Theme.fg : Theme.line)
                .frame(width: 10, height: 2)
                .frame(height: 14)
        } else if i <= feel.level {
            RoundedRectangle(cornerRadius: 2).fill(Theme.fg).frame(width: 10, height: 14)
        } else {
            RoundedRectangle(cornerRadius: 2).strokeBorder(Theme.line, lineWidth: 1).frame(width: 10, height: 14)
        }
    }
}
