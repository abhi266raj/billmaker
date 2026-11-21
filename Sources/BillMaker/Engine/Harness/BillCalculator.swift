import Foundation

/// Core mathematical and business logic engine for calculating line-item costs, subtotals,
/// unit conversions, metrics (weight in kg, item count), and cumulative live bill state merging.
///
/// `BillCalculator` is shared by both local and LLM parsing workflows to ensure that all math,
/// unit conversions, duplicate-item resolutions, and tax calculations are identical and accurate.
public struct BillCalculator {
    /// Computes a single line-item (`BilledItem`) from an `AgentParsedItem`.
    ///
    /// Handles subunit scaling within the same dimension:
    /// - Grams to Kilograms (e.g., 500g -> 0.5 kg)
    /// - Kilograms to Grams (e.g., 1kg -> 1000 g)
    /// - Millilitres to Litres (e.g., 500ml -> 0.5 L)
    /// - Pieces to Dozens (e.g., 6 pcs -> 0.5 dozen)
    ///
    /// - Parameters:
    ///   - parsed: The item extracted by the parsing engine (`AgentParsedItem`).
    ///   - catalog: Active store inventory items for price lookups.
    /// - Returns: A fully-calculated `BilledItem` with unit price, subtotal, and optional weight in kg.
    public static func computeSingleItem(
        parsed: AgentParsedItem,
        catalog: [Item]
    ) -> BilledItem {
        let matchedCatalogItem: Item? = {
            if let idStr = parsed.itemId, let uuid = UUID(uuidString: idStr) {
                if let found = catalog.first(where: { $0.id == uuid }) {
                    return found
                }
            }
            let cleanName = parsed.itemName.lowercased().trimmingCharacters(in: .whitespaces)
            return catalog.first { item in
                item.name.lowercased() == cleanName ||
                item.aliases.contains { $0.lowercased() == cleanName }
            }
        }()

        let unitPrice = parsed.unitPrice ?? matchedCatalogItem?.pricePerUnit ?? 0.0
        let itemName = matchedCatalogItem?.name ?? parsed.itemName
        let unitType: UnitType = {
            if let catItem = matchedCatalogItem {
                return catItem.unitType
            }
            return UnitType(rawValue: parsed.unit.lowercased()) ?? .piece
        }()

        var normalizedQuantity = parsed.quantity
        let rawUnit = parsed.unit.lowercased().trimmingCharacters(in: .whitespaces)

        // Subunit scaling within the same measurement dimension
        if unitType == .kg && (rawUnit == "g" || rawUnit == "gram" || rawUnit == "grams" || rawUnit == "gm") {
            normalizedQuantity = parsed.quantity / 1000.0
        } else if unitType == .gram && (rawUnit == "kg" || rawUnit == "kilo" || rawUnit == "kilogram") {
            normalizedQuantity = parsed.quantity * 1000.0
        } else if unitType == .litre && (rawUnit == "ml" || rawUnit == "millilitre") {
            normalizedQuantity = parsed.quantity / 1000.0
        } else if unitType == .dozen && (rawUnit == "piece" || rawUnit == "pc" || rawUnit == "pcs") {
            normalizedQuantity = parsed.quantity / 12.0
        }

        let subtotal = normalizedQuantity * unitPrice

        // Weight metric tracking for shipping / bagging
        var weightInKg: Double? = nil
        if unitType == .kg {
            weightInKg = normalizedQuantity
        } else if unitType == .gram {
            weightInKg = normalizedQuantity / 1000.0
        }

        return BilledItem(
            id: UUID(),
            itemId: matchedCatalogItem?.id,
            name: itemName,
            matchedAlias: parsed.matchedAlias,
            quantity: normalizedQuantity,
            unit: unitType,
            unitPrice: unitPrice,
            subtotal: subtotal,
            weightInKg: weightInKg
        )
    }

    /// Computes a complete `BillSummary` for a collection of parsed items.
    ///
    /// - Parameters:
    ///   - parsedItems: Array of extracted item entries.
    ///   - catalog: Active store inventory items.
    ///   - currencySymbol: Currency display symbol (e.g. "₹", "$").
    ///   - taxRatePercent: Percentage tax to apply (e.g. 5.0 for 5%).
    ///   - discountAmount: Fixed discount amount to deduct.
    /// - Returns: A complete `BillSummary` with itemized list, taxes, weights, and grand total.
    public static func computeBill(
        from parsedItems: [AgentParsedItem],
        catalog: [Item],
        currencySymbol: String = "₹",
        taxRatePercent: Double = 0.0,
        discountAmount: Double = 0.0
    ) -> BillSummary {
        let billedItems = parsedItems.map { computeSingleItem(parsed: $0, catalog: catalog) }
        return BillSummary(
            id: UUID(),
            items: billedItems,
            taxRatePercent: taxRatePercent,
            discountAmount: discountAmount,
            currencySymbol: currencySymbol,
            createdAt: Date()
        )
    }

    /// Merges newly parsed items into an existing cumulative live bill.
    ///
    /// Implements store policy when an item is re-entered:
    /// - **Add**: Combines quantities (e.g., previously 1kg + new 2kg = 3kg).
    /// - **Replace**: Overwrites the existing quantity with the newly specified quantity.
    ///
    /// - Parameters:
    ///   - existingBill: The current active live bill summary (if any).
    ///   - newParsedItems: Newly extracted items from the user's latest message.
    ///   - catalog: Active store inventory items.
    ///   - currencySymbol: Currency display symbol.
    ///   - taxRatePercent: Percentage tax.
    ///   - discountAmount: Fixed discount.
    ///   - replaceExisting: `true` to replace quantity; `false` to add cumulative quantity.
    /// - Returns: An updated `BillSummary` reflecting the cumulative invoice state.
    public static func mergeIntoBill(
        existingBill: BillSummary?,
        newParsedItems: [AgentParsedItem],
        catalog: [Item],
        currencySymbol: String = "₹",
        taxRatePercent: Double = 0.0,
        discountAmount: Double = 0.0,
        replaceExisting: Bool = false
    ) -> BillSummary {
        var currentItems: [BilledItem] = existingBill?.items ?? []

        for parsed in newParsedItems {
            let newItem = computeSingleItem(parsed: parsed, catalog: catalog)

            if let existingIndex = currentItems.firstIndex(where: {
                ($0.itemId != nil && newItem.itemId != nil && $0.itemId == newItem.itemId) ||
                $0.name.lowercased() == newItem.name.lowercased()
            }) {
                if replaceExisting {
                    currentItems[existingIndex] = newItem
                } else {
                    let combinedQty = currentItems[existingIndex].quantity + newItem.quantity
                    let combinedSubtotal = combinedQty * currentItems[existingIndex].unitPrice
                    let combinedWeight: Double? = {
                        if currentItems[existingIndex].unit == .kg {
                            return combinedQty
                        } else if currentItems[existingIndex].unit == .gram {
                            return combinedQty / 1000.0
                        }
                        return nil
                    }()

                    currentItems[existingIndex].quantity = combinedQty
                    currentItems[existingIndex].subtotal = combinedSubtotal
                    currentItems[existingIndex].weightInKg = combinedWeight
                }
            } else {
                currentItems.append(newItem)
            }
        }

        return BillSummary(
            id: existingBill?.id ?? UUID(),
            items: currentItems,
            taxRatePercent: taxRatePercent,
            discountAmount: discountAmount,
            currencySymbol: currencySymbol,
            createdAt: existingBill?.createdAt ?? Date()
        )
    }
}
