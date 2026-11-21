import SwiftUI

public struct ChatMessageBubble: View {
    let message: AgentMessage
    let onInspectJson: (String) -> Void
    var onUndo: (() -> Void)? = nil
    @State private var isThoughtExpanded: Bool = true

    public init(
        message: AgentMessage,
        onInspectJson: @escaping (String) -> Void,
        onUndo: (() -> Void)? = nil
    ) {
        self.message = message
        self.onInspectJson = onInspectJson
        self.onUndo = onUndo
    }

    public var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if message.role == .user {
                Spacer(minLength: 50)
                VStack(alignment: .trailing, spacing: 4) {
                    Text(message.text)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                    Text(message.timestamp.formatted(date: .omitted, time: .shortened))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .padding(.trailing, 4)
                }
            } else {
                // Agent Avatar
                ZStack {
                    Circle()
                        .fill(agentAvatarColor.opacity(0.15))
                        .frame(width: 32, height: 32)
                    Image(systemName: agentAvatarIcon)
                        .foregroundColor(agentAvatarColor)
                        .font(.system(size: 15))
                }

                VStack(alignment: .leading, spacing: 8) {
                    // Thought Process Section (if available)
                    if let thought = message.thoughtProcess, !thought.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    isThoughtExpanded.toggle()
                                }
                            }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "brain.head.profile")
                                        .foregroundColor(.purple)
                                        .font(.caption)
                                    Text("Thought Process")
                                        .font(.caption.weight(.semibold))
                                        .foregroundColor(.purple)
                                    Spacer()
                                    Image(systemName: isThoughtExpanded ? "chevron.up" : "chevron.down")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .buttonStyle(.plain)

                            if isThoughtExpanded {
                                Text(thought)
                                    .font(.system(.caption2, design: .monospaced))
                                    .foregroundColor(.primary.opacity(0.85))
                                    .lineSpacing(2)
                                    .padding(8)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color(NSColor.controlBackgroundColor).opacity(0.7))
                                    .cornerRadius(6)
                                    .transition(.opacity.combined(with: .move(edge: .top)))
                            }
                        }
                        .padding(8)
                        .background(Color.purple.opacity(0.08))
                        .cornerRadius(10)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.purple.opacity(0.2), lineWidth: 1))
                    }

                    // Main Human Conversational Text
                    VStack(alignment: .leading, spacing: 8) {
                        Text(message.text)
                            .font(.body)
                            .foregroundColor(.primary)
                            .fixedSize(horizontal: false, vertical: true)

                        // Auto-correction note & Undo row
                        if message.hasAutoCorrection, let note = message.autoCorrectionNote {
                            HStack(spacing: 8) {
                                HStack(spacing: 4) {
                                    Image(systemName: "wand.and.stars")
                                        .font(.caption2)
                                    Text(note)
                                        .font(.caption2)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color.orange.opacity(0.12))
                                .foregroundColor(.orange)
                                .cornerRadius(6)

                                if let undoAction = onUndo {
                                    Button(action: undoAction) {
                                        HStack(spacing: 3) {
                                            Image(systemName: "arrow.uturn.backward")
                                            Text("Undo")
                                        }
                                        .font(.caption2.weight(.semibold))
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 3)
                                        .background(Color.red.opacity(0.12))
                                        .foregroundColor(.red)
                                        .cornerRadius(6)
                                    }
                                    .buttonStyle(.plain)
                                    .help("Undo this auto-corrected item addition")
                                }
                            }
                        }

                        // Unit mismatch correction note & Undo row
                        if let unitNotes = message.unitCorrectionNotes, !unitNotes.isEmpty {
                            HStack(spacing: 8) {
                                HStack(spacing: 4) {
                                    Image(systemName: "scalemass.fill")
                                        .font(.caption2)
                                    Text(unitNotes.joined(separator: "; "))
                                        .font(.caption2)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color.blue.opacity(0.12))
                                .foregroundColor(.blue)
                                .cornerRadius(6)

                                if !message.hasAutoCorrection, let undoAction = onUndo {
                                    Button(action: undoAction) {
                                        HStack(spacing: 3) {
                                            Image(systemName: "arrow.uturn.backward")
                                            Text("Undo")
                                        }
                                        .font(.caption2.weight(.semibold))
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 3)
                                        .background(Color.red.opacity(0.12))
                                        .foregroundColor(.red)
                                        .cornerRadius(6)
                                    }
                                    .buttonStyle(.plain)
                                    .help("Undo this unit-corrected item addition")
                                }
                            }
                        }

                        // Status & JSON inspect button row
                        HStack(spacing: 8) {
                            statusBadge

                            Spacer()

                            if let json = message.rawJsonOutput, !json.isEmpty {
                                Button(action: { onInspectJson(json) }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "curlybraces")
                                        Text("View JSON")
                                    }
                                    .font(.caption2.weight(.medium))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.secondary.opacity(0.12))
                                    .cornerRadius(6)
                                }
                                .buttonStyle(.plain)
                                .help("Inspect extracted JSON payload sent to billing harness")
                            }

                            Text(message.timestamp.formatted(date: .omitted, time: .shortened))
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(12)
                    .background(Color(NSColor.controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.secondary.opacity(0.15), lineWidth: 1))
                }
                Spacer(minLength: 50)
            }
        }
    }

    private var agentAvatarColor: Color {
        switch message.status {
        case .ready: return .green
        case .needsClarification: return .orange
        case .thinking: return .blue
        case .error: return .red
        case .info: return .purple
        }
    }

    private var agentAvatarIcon: String {
        switch message.status {
        case .ready: return "checkmark.seal.fill"
        case .needsClarification: return "questionmark.bubble.fill"
        case .thinking: return "hourglass"
        case .error: return "exclamationmark.triangle.fill"
        case .info: return "sparkles"
        }
    }

    @ViewBuilder
    private var statusBadge: some View {
        switch message.status {
        case .ready:
            HStack(spacing: 3) {
                Circle().fill(Color.green).frame(width: 6, height: 6)
                Text("Bill Calculated").font(.caption2).foregroundColor(.green)
            }
        case .needsClarification:
            HStack(spacing: 3) {
                Circle().fill(Color.orange).frame(width: 6, height: 6)
                Text("Needs Clarification").font(.caption2).foregroundColor(.orange)
            }
        case .error:
            HStack(spacing: 3) {
                Circle().fill(Color.red).frame(width: 6, height: 6)
                Text("Error").font(.caption2).foregroundColor(.red)
            }
        case .info, .thinking:
            EmptyView()
        }
    }
}
