import SwiftUI

public struct PromptSuggestionBar: View {
    let samplePrompts: [String]
    let onSelectPrompt: (String) -> Void

    public init(samplePrompts: [String], onSelectPrompt: @escaping (String) -> Void) {
        self.samplePrompts = samplePrompts
        self.onSelectPrompt = onSelectPrompt
    }

    public var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Text("Try:")
                    .font(.caption2.weight(.medium))
                    .foregroundColor(.secondary)

                ForEach(samplePrompts, id: \.self) { prompt in
                    Button(action: { onSelectPrompt(prompt) }) {
                        Text(prompt)
                            .font(.caption)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color.secondary.opacity(0.1))
                            .cornerRadius(12)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .background(Color(NSColor.windowBackgroundColor).opacity(0.6))
    }
}
