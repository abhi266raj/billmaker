import SwiftUI

public struct InvoiceItemRowView: View {
    let item: BilledItem
    let currencySymbol: String

    public var body: some View {
        HStack(alignment: .top) {
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

            Text("\(item.quantity.cleanFormatted) \(item.unit.shortLabel)")
                .font(.callout)
                .frame(width: 60, alignment: .trailing)

            Text("\(currencySymbol)\(item.unitPrice.cleanFormatted)")
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 70, alignment: .trailing)

            Text("\(currencySymbol)\(String(format: "%.2f", item.subtotal))")
                .font(.callout.weight(.semibold))
                .frame(width: 80, alignment: .trailing)
        }
        .padding(.vertical, 2)
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
