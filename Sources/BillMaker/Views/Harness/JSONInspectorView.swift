import SwiftUI

public struct JSONInspectorView: View {
    @Environment(\.dismiss) private var dismiss
    let jsonText: String

    public init(jsonText: String) {
        self.jsonText = jsonText
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack {
                    Text("Agent Structured JSON Output")
                        .font(.headline)
                    Spacer()
                    Button(action: copyToClipboard) {
                        Label("Copy JSON", systemImage: "doc.on.doc")
                    }
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))

                Divider()

                ScrollView {
                    Text(jsonText)
                        .font(.system(.body, design: .monospaced))
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                }
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .frame(minWidth: 500, minHeight: 400)
        }
    }

    private func copyToClipboard() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(jsonText, forType: .string)
    }
}
