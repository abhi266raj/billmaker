import SwiftUI

public enum JSONFormatter {
    public static func prettyPrint(_ raw: String) -> String {
        guard !raw.isEmpty,
              let data = raw.data(using: .utf8),
              let jsonObject = try? JSONSerialization.jsonObject(with: data, options: []),
              let prettyData = try? JSONSerialization.data(withJSONObject: jsonObject, options: [.prettyPrinted, .sortedKeys]),
              let prettyString = String(data: prettyData, encoding: .utf8) else {
            return raw
        }
        return prettyString
    }
}

public struct JSONInspectorView: View {
    @Environment(\.dismiss) private var dismiss
    let jsonText: String

    public init(jsonText: String) {
        self.jsonText = JSONFormatter.prettyPrint(jsonText)
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
