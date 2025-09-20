import SwiftUI

struct CardView<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color(.systemBackground)).shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4))
    }
}

#Preview {
    CardView {
        Text("Sample Card")
    }
    .padding()
}
