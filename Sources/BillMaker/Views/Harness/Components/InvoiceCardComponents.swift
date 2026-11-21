import SwiftUI

public struct InvoiceItemRowView: View {
    let item: BilledItem
    let currencySymbol: String
    var onUpdateQuantity: ((Double) -> Void)? = nil
    var onRemove: (() -> Void)? = nil

    private var stepAmount: Double {
        switch item.unit {
        case .kg, .litre: return 0.5
        case .gram: return 100.0
        case .ml: return 100.0
        case .piece, .packet, .dozen: return 1.0
        }
    }

    public init(
        item: BilledItem,
        currencySymbol: String,
        onUpdateQuantity: ((Double) -> Void)? = nil,
        onRemove: (() -> Void)? = nil
    ) {
        self.item = item
        self.currencySymbol = currencySymbol
        self.onUpdateQuantity = onUpdateQuantity
        self.onRemove = onRemove
    }

    public var body: some View {
        HStack(alignment: .center, spacing: 6) {
            // Item Name & Matched note
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.body.weight(.medium))
                if let alias = item.matchedAlias, !alias.isEmpty, alias.lowercased() != item.name.lowercased() {
                    Text("matched: \"\(alias)\"")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Quantity stepper & controls
            if let updateQty = onUpdateQuantity {
                HStack(spacing: 4) {
                    Button(action: {
                        let newQty = max(0, item.quantity - stepAmount)
                        updateQty(newQty)
                    }) {
                        Image(systemName: "minus.circle")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Decrease quantity")

                    Text("\(item.quantity.cleanFormatted) \(item.unit.shortLabel)")
                        .font(.callout.weight(.medium))
                        .frame(minWidth: 48, alignment: .center)

                    Button(action: {
                        let newQty = item.quantity + stepAmount
                        updateQty(newQty)
                    }) {
                        Image(systemName: "plus.circle")
                            .font(.caption)
                            .foregroundColor(.accentColor)
                    }
                    .buttonStyle(.plain)
                    .help("Increase quantity")
                }
            } else {
                Text("\(item.quantity.cleanFormatted) \(item.unit.shortLabel)")
                    .font(.callout)
                    .frame(width: 60, alignment: .trailing)
            }

            // Subtotal
            Text("\(currencySymbol)\(String(format: "%.2f", item.subtotal))")
                .font(.callout.weight(.semibold))
                .frame(width: 65, alignment: .trailing)

            // Remove button
            if let removeAction = onRemove {
                Button(action: removeAction) {
                    Image(systemName: "trash")
                        .font(.caption2)
                        .foregroundColor(.red.opacity(0.75))
                }
                .buttonStyle(.plain)
                .help("Remove \(item.name) from bill")
            }
        }
        .padding(.vertical, 3)
    }
}

public struct InvoiceMetricsView: View {
    let bill: BillSummary

    public var body: some View {
        HStack(spacing: 12) {
            if bill.totalWeightKg > 0 {
                VStack(alignment: .leading, spacing: 2) {
                    Text("TOTAL WEIGHT")
                        .font(.system(size: 9).weight(.bold))
                        .foregroundColor(.secondary)
                    Text("\(String(format: "%.2f", bill.totalWeightKg)) kg")
                        .font(.callout.weight(.medium))
                        .foregroundColor(.indigo)
                }
            }

            if bill.totalPieceCount > 0 {
                VStack(alignment: .leading, spacing: 2) {
                    Text("TOTAL PIECES")
                        .font(.system(size: 9).weight(.bold))
                        .foregroundColor(.secondary)
                    Text("\(bill.totalPieceCount.cleanFormatted) pcs")
                        .font(.callout.weight(.medium))
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("TOTAL ITEMS")
                    .font(.system(size: 9).weight(.bold))
                    .foregroundColor(.secondary)
                Text("\(bill.totalItemsCount)")
                    .font(.callout.weight(.medium))
            }
        }
        .padding(8)
        .background(Color.secondary.opacity(0.06))
        .cornerRadius(8)
    }
}

public struct InvoiceTotalsView: View {
    let bill: BillSummary

    public var body: some View {
        VStack(spacing: 6) {
            HStack {
                Text("Subtotal")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(bill.currencySymbol)\(String(format: "%.2f", bill.subtotal))")
                    .font(.subheadline)
            }

            if bill.taxRatePercent > 0 {
                HStack {
                    Text("Tax (\(bill.taxRatePercent.cleanFormatted)%)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(bill.currencySymbol)\(String(format: "%.2f", bill.taxAmount))")
                        .font(.subheadline)
                }
            }

            if bill.discountAmount > 0 {
                HStack {
                    Text("Discount")
                        .font(.subheadline)
                        .foregroundColor(.green)
                    Spacer()
                    Text("-\(bill.currencySymbol)\(String(format: "%.2f", bill.discountAmount))")
                        .font(.subheadline)
                        .foregroundColor(.green)
                }
            }

            HStack {
                Text("Grand Total")
                    .font(.title3.weight(.bold))
                Spacer()
                Text("\(bill.currencySymbol)\(String(format: "%.2f", bill.grandTotal))")
                    .font(.title2.weight(.bold))
                    .foregroundColor(.accentColor)
            }
            .padding(.top, 4)
        }
    }
}
