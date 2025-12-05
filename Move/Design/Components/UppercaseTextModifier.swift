import SwiftUI

private struct UppercaseTextModifier: ViewModifier {
    func body(content: Content) -> some View {
        content.transformEnvironment(\.textCase) { value in
            value = .uppercase
        }
    }
}

extension View {
    func uppercaseTextEnvironment() -> some View {
        modifier(UppercaseTextModifier())
    }
}
