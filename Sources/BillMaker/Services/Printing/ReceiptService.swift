import AppKit

public struct ReceiptService {
    public static func generateReceiptText(for bill: BillSummary) -> String {
        var text = "=== TAX INVOICE ===\n"
        text += "Date: \(bill.createdAt.formatted())\n"
        text += "----------------------------------------\n"

        for item in bill.items {
            let aliasNote = (item.matchedAlias != nil && item.matchedAlias?.lowercased() != item.name.lowercased())
                ? " (\(item.matchedAlias!))" : ""
            text += "\(item.name)\(aliasNote)\n"
            text += "  \(item.quantity.cleanFormatted) \(item.unit.shortLabel) @ \(bill.currencySymbol)\(item.unitPrice.cleanFormatted) = \(bill.currencySymbol)\(String(format: "%.2f", item.subtotal))\n"
        }

        text += "----------------------------------------\n"
        if bill.totalWeightKg > 0 {
            text += "Total Weight: \(String(format: "%.2f", bill.totalWeightKg)) kg\n"
        }
        if bill.totalPieceCount > 0 {
            text += "Total Pieces: \(bill.totalPieceCount.cleanFormatted) pcs\n"
        }
        text += "Total Items: \(bill.totalItemsCount)\n"
        text += "Subtotal: \(bill.currencySymbol)\(String(format: "%.2f", bill.subtotal))\n"

        if bill.taxAmount > 0 {
            text += "Tax (\(bill.taxRatePercent.cleanFormatted)%): \(bill.currencySymbol)\(String(format: "%.2f", bill.taxAmount))\n"
        }
        if bill.discountAmount > 0 {
            text += "Discount: -\(bill.currencySymbol)\(String(format: "%.2f", bill.discountAmount))\n"
        }

        text += "GRAND TOTAL: \(bill.currencySymbol)\(String(format: "%.2f", bill.grandTotal))\n"
        text += "========================================\n"
        return text
    }

    public static func copyReceiptToClipboard(for bill: BillSummary) {
        let text = generateReceiptText(for: bill)
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    public static func printReceipt(for bill: BillSummary) {
        let text = generateReceiptText(for: bill)
        let printView = NSTextView(frame: NSRect(x: 0, y: 0, width: 400, height: 600))
        printView.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        printView.string = text

        let printOperation = NSPrintOperation(view: printView)
        printOperation.showsPrintPanel = true
        printOperation.run()
    }
}
