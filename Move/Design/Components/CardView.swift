import SwiftUI

struct CardView<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(.vertical, 24)
            .padding(.horizontal, 20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(MoveTheme.background)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .stroke(MoveTheme.primary, lineWidth: 3)
                    )
            )
            .foregroundStyle(MoveTheme.text)
    }
}

#Preview {
    CardView {
        Text("Sample Card")
    }
    .padding()
}
