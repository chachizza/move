import SwiftUI

struct EmptyStateView: View {
    let emoji: String
    let title: String
    let message: String
    let actionTitle: String?
    let action: (() -> Void)?

    init(emoji: String, title: String, message: String, actionTitle: String? = nil, action: (() -> Void)? = nil) {
        self.emoji = emoji
        self.title = title
        self.message = message
        self.actionTitle = actionTitle
        self.action = action
    }

    var body: some View {
        VStack(spacing: 12) {
            Text(emoji).font(.system(size: 56))
            Text(title)
                .font(.title3)
                .fontWeight(.heavy)
            Text(message)
                .font(.body)
                .foregroundStyle(MoveTheme.muted)
                .multilineTextAlignment(.center)
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.primary)
            }
        }
        .padding(32)
    }
}

#Preview {
    EmptyStateView(emoji: "✨", title: "No Reminders", message: "Schedule exercises to get started", actionTitle: "Add", action: {})
}
