import SwiftUI

/// Four cells, same visual language as the signal bar. Cell i sets strength i.
struct StrengthBar: View {
    @Binding var strength: Int
    let label: String

    var body: some View {
        HStack(spacing: 8) {
            HStack(spacing: 0) {
                ForEach(1...4, id: \.self) { i in
                    Group {
                        if i <= strength {
                            RoundedRectangle(cornerRadius: 2).fill(Theme.fg)
                        } else {
                            RoundedRectangle(cornerRadius: 2).strokeBorder(Theme.line, lineWidth: 1)
                        }
                    }
                    .frame(width: 10, height: 14)
                    .frame(width: 13, height: Theme.row, alignment: .leading)
                    .contentShape(Rectangle())
                    .onTapGesture { strength = i }
                }
            }
            .padding(.trailing, -3)
            Text("\(strength) / 4")
                .font(Theme.font(11))
                .foregroundColor(Theme.fg2)
                .frame(width: 48, alignment: .leading)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue("\(strength) of 4")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: strength = min(strength + 1, 4)
            case .decrement: strength = max(strength - 1, 1)
            @unknown default: break
            }
        }
    }
}
