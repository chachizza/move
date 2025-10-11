import SwiftUI

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .textCase(.uppercase)
            .padding(.vertical, 16)
            .padding(.horizontal, 20)
            .frame(maxWidth: .infinity)
            .background(MoveTheme.primary)
            .foregroundColor(MoveTheme.background)
            .overlay(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .stroke(MoveTheme.canvas, lineWidth: 3)
            )
            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
            .opacity(configuration.isPressed ? 0.7 : 1.0)
    }
}

extension ButtonStyle where Self == PrimaryButtonStyle {
    static var primary: PrimaryButtonStyle { PrimaryButtonStyle() }
}
