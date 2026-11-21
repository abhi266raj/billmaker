import SwiftUI

public struct LiveInvoiceView: View {
    let bill: BillSummary?
    @Binding var duplicatePolicy: DuplicateItemPolicy
    let canUndo: Bool
    let onUndo: () -> Void
    let onReset: () -> Void
    let onInspectJson: (() -> Void)?

    public init(
        bill: BillSummary?,
        duplicatePolicy: Binding<DuplicateItemPolicy>,
        canUndo: Bool = false,
        onUndo: @escaping () -> Void = {},
        onReset: @escaping () -> Void,
        onInspectJson: (() -> Void)? = nil
    ) {
        self.bill = bill
        self._duplicatePolicy = duplicatePolicy
        self.canUndo = canUndo
        self.onUndo = onUndo
        self.onReset = onReset
        self.onInspectJson = onInspectJson
    }

    public var body: some View {
        VStack(spacing: 0) {
            headerBar
            Divider()

            policyBar
            Divider()

            if let bill = bill, !bill.items.isEmpty {
                ScrollView {
                    VStack(spacing: 16) {
                        invoiceCard(bill)
                        actionButtons(bill)
                    }
                    .padding()
                }
            } else {
                emptyInvoiceState
            }
        }
    }

    private var headerBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Image(systemName: "receipt")
                        .foregroundColor(.accentColor)
                    Text("Live Bill Harness")
                        .font(.headline)
                    Text("LIVE")
                        .font(.system(size: 9).weight(.bold))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color.green.opacity(0.18))
                        .foregroundColor(.green)
                        .cornerRadius(4)
                }
                Text("Accumulates items until reset via UX")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Spacer()

            if canUndo {
                Button(action: onUndo) {
                    Label("Undo Last Action", systemImage: "arrow.uturn.backward")
                        .font(.caption.weight(.semibold))
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.orange.opacity(0.85))
                .keyboardShortcut("z", modifiers: .command)
                .help("Undo the last added item (Cmd+Z or type 'undo')")
            }

            if let bill = bill, !bill.items.isEmpty {
                Button(action: onReset) {
                    Label("Reset Bill", systemImage: "arrow.counterclockwise")
                        .font(.caption.weight(.medium))
                        .foregroundColor(.red)
                }
                .buttonStyle(.bordered)
                .help("Clear active bill and start a new transaction")
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
    }

    private var policyBar: some View {
        HStack(spacing: 8) {
            Text("If item re-entered:")
                .font(.caption2)
                .foregroundColor(.secondary)

            Picker("", selection: $duplicatePolicy) {
                ForEach(DuplicateItemPolicy.allCases) { policy in
                    Text(policy.displayName).tag(policy)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 240)
        }
        .padding(.horizontal)
        .padding(.vertical, 6)
        .background(Color(NSColor.windowBackgroundColor).opacity(0.5))
    }

    private func invoiceCard(_ bill: BillSummary) -> some View {
        VStack(spacing: 12) {
            HStack {
                Text("TAX INVOICE")
                    .font(.caption2.weight(.bold))
                    .foregroundColor(.secondary)
                Spacer()
                Text(bill.createdAt.formatted(date: .numeric, time: .shortened))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Divider()

            VStack(spacing: 8) {
                tableColumnHeader
                ForEach(bill.items) { item in
                    InvoiceItemRowView(item: item, currencySymbol: bill.currencySymbol)
                }
            }

            Divider()
            InvoiceMetricsView(bill: bill)
            Divider()
            InvoiceTotalsView(bill: bill)
        }
        .padding(16)
        .background(Color(NSColor.textBackgroundColor))
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.secondary.opacity(0.2), lineWidth: 1))
        .shadow(color: Color.black.opacity(0.04), radius: 6, y: 2)
    }

    private var tableColumnHeader: some View {
        HStack {
            Text("ITEM")
                .font(.caption2.weight(.bold))
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("QTY")
                .font(.caption2.weight(.bold))
                .foregroundColor(.secondary)
                .frame(width: 60, alignment: .trailing)
            Text("RATE")
                .font(.caption2.weight(.bold))
                .foregroundColor(.secondary)
                .frame(width: 70, alignment: .trailing)
            Text("AMOUNT")
                .font(.caption2.weight(.bold))
                .foregroundColor(.secondary)
                .frame(width: 80, alignment: .trailing)
        }
    }

    private func actionButtons(_ bill: BillSummary) -> some View {
        HStack(spacing: 12) {
            Button(action: { ReceiptService.copyReceiptToClipboard(for: bill) }) {
                Label("Copy Receipt", systemImage: "doc.on.doc")
            }
            .buttonStyle(.bordered)

            Button(action: { ReceiptService.printReceipt(for: bill) }) {
                Label("Print Invoice", systemImage: "printer")
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var emptyInvoiceState: some View {
        VStack(spacing: 16) {
            Image(systemName: "cart")
                .font(.system(size: 48))
                .foregroundColor(.secondary.opacity(0.5))

            VStack(spacing: 4) {
                Text("No Active Bill")
                    .font(.headline)
                Text("Enter items on the left. Items will accumulate here until you reset.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}
