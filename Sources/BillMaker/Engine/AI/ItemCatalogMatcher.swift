import Foundation

/// Provides lexical matching, colloquial alias resolution, and false-match prevention for retail grocery items.
public struct ItemCatalogMatcher {
    /// Common stop-words and quantity descriptors to strip when isolating requested item keywords.
    private static let stopWords: Set<String> = [
        "1", "2", "3", "4", "5", "6", "7", "8", "9", "0",
        "kg", "kilo", "kilos", "kilogram", "kilograms", "gm", "g", "gram", "grams",
        "l", "ltr", "litre", "litres", "liter", "liters", "ml", "packet", "packets", "pkt",
        "dozen", "doz", "pc", "pcs", "piece", "pieces",
        "dedh", "dhai", "aadha", "paav", "ek", "do", "teen", "char",
        "aur", "and", "do", "de", "dedo", "chahiye", "please", "add", "to", "the", "bill", "cart",
        "rupees", "rs", "₹", "ka", "ki", "ke", "wali", "wala"
    ]

    /// Returns multilingual colloquial aliases (Hindi/Hinglish/English) for a given catalog item name.
    public static func aliases(for itemName: String) -> [String] {
        let lower = itemName.lowercased()
        var list: [String] = [lower]

        let words = lower.components(separatedBy: CharacterSet.alphanumerics.inverted).filter { $0.count >= 2 }
        list.append(contentsOf: words)

        if lower.contains("potato") {
            list.append(contentsOf: ["aloo", "alu", "batata", "potatoes"])
        }
        if lower.contains("tomato") {
            list.append(contentsOf: ["tamatar", "tomatoes"])
        }
        if lower.contains("onion") {
            list.append(contentsOf: ["pyaz", "pyaaz", "kanda", "onions"])
        }
        if lower.contains("cow milk") || lower.contains("milk") {
            list.append(contentsOf: ["doodh", "dudh", "milk"])
        }
        if lower.contains("curd") {
            list.append(contentsOf: ["dahi", "curd"])
        }
        if lower.contains("paneer") {
            list.append(contentsOf: ["cottage cheese", "paneer"])
        }
        if lower.contains("mustard oil") || lower.contains("mustard") {
            list.append(contentsOf: ["sarson", "sarso", "sarson tel", "sarso tel", "sarson ka tel", "sarso ka tel", "mustard oil", "mustard", "rai"])
        }
        if lower.contains("sunflower oil") || lower.contains("sunflower") {
            list.append(contentsOf: ["surajmukhi", "soorajmukhi", "surajmukhi tel", "sunflower oil", "sunflower"])
        }
        if lower.contains("rice") {
            list.append(contentsOf: ["chawal", "rice", "bhat", "basmati", "basmati rice", "basmati chawal"])
        }
        if lower.contains("atta") || lower.contains("flour") || lower.contains("wheat") {
            list.append(contentsOf: ["atta", "aata", "wheat flour", "gehun", "flour", "gehun ka atta"])
        }
        if lower.contains("curd") {
            list.append(contentsOf: ["dahi", "curd", "yogurt"])
        }
        if lower.contains("sugar") {
            list.append(contentsOf: ["cheeni", "chini", "shakkar", "sugar"])
        }
        if lower.contains("salt") {
            list.append(contentsOf: ["namak", "salt", "sendha namak", "tata salt"])
        }
        if lower.contains("egg") {
            list.append(contentsOf: ["anda", "ande", "eggs", "egg"])
        }
        if lower.contains("banana") {
            list.append(contentsOf: ["kela", "kele", "banana", "bananas"])
        }
        if lower.contains("apple") {
            list.append(contentsOf: ["seb", "apple", "apples"])
        }
        if lower.contains("maggi") {
            list.append(contentsOf: ["maggi", "noodles", "maggie", "maggi noodles"])
        }
        if lower.contains("ginger") {
            list.append(contentsOf: ["adrak", "ginger", "adrakh"])
        }

        return Array(Set(list))
    }

    /// Checks if a returned catalog item name has a valid semantic or lexical link to the user's input query.
    public static func itemMatchesUserInput(itemName: String, userInput: String) -> Bool {
        let cleanInput = userInput.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        if cleanInput.isEmpty { return true }

        let itemAliases = aliases(for: itemName)
        for alias in itemAliases {
            if cleanInput.contains(alias) {
                return true
            }
        }

        let words = cleanInput.components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.count >= 3 && !stopWords.contains($0) }

        for word in words {
            for alias in itemAliases {
                if alias.contains(word) || word.contains(alias) {
                    return true
                }
            }
        }

        return false
    }

    /// Extracts the core requested item subject from user input by removing quantities and stop words.
    public static func extractRequestedItemSubject(from userInput: String) -> String? {
        let cleanInput = userInput.lowercased()
        let tokens = cleanInput.components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty && !stopWords.contains($0) }

        if tokens.isEmpty { return nil }
        return tokens.joined(separator: " ")
    }

    /// Checks whether the user's input is a generic oil query without specifying the variety.
    public static func isGenericOilQuery(_ userInput: String) -> Bool {
        let lower = userInput.lowercased()
        let mentionsOil = lower.contains("oil") || lower.contains("tel")
        guard mentionsOil else { return false }

        let hasSpecificVariety = lower.contains("mustard") ||
            lower.contains("sarson") ||
            lower.contains("sarso") ||
            lower.contains("sunflower") ||
            lower.contains("surajmukhi") ||
            lower.contains("soorajmukhi") ||
            lower.contains("coconut") ||
            lower.contains("nariyal") ||
            lower.contains("olive") ||
            lower.contains("sesame") ||
            lower.contains("til") ||
            lower.contains("refined")

        return !hasSpecificVariety
    }

    /// Converts Devanagari numerals ('०'-'९') to standard Western digits ('0'-'9').
    public static func normalizeNumerals(_ text: String) -> String {
        let devanagariDigits: [Character: Character] = [
            "०": "0", "१": "1", "२": "2", "३": "3", "४": "4",
            "५": "5", "६": "6", "७": "7", "८": "8", "९": "9"
        ]
        return String(text.map { devanagariDigits[$0] ?? $0 })
    }

    /// Normalizes colloquial Hindi/Hinglish quantities to standard numerical values.
    public static func normalizeColloquials(_ text: String) -> String {
        var str = normalizeNumerals(text.lowercased())
        let replacements: [(String, String)] = [
            ("aadha kilo", "0.5 kg"),
            ("adha kilo", "0.5 kg"),
            ("aadha kg", "0.5 kg"),
            ("dedh kilo", "1.5 kg"),
            ("dedh kg", "1.5 kg"),
            ("dhai kilo", "2.5 kg"),
            ("dhai kg", "2.5 kg"),
            ("paav kilo", "0.25 kg"),
            ("ek paav", "0.25 kg"),
            ("teen paav", "0.75 kg"),
            ("dhai sau gram", "250g"),
            ("dhai sau gm", "250g"),
            ("panch sau gram", "500g"),
            ("half dozen", "0.5 dozen"),
            ("aadha darjan", "0.5 dozen"),
            ("ek darjan", "1 dozen")
        ]
        for (pattern, rep) in replacements {
            str = str.replacingOccurrences(of: pattern, with: rep)
        }
        return str
    }

    /// Resolves user's conversational reply to a pending clarification (handling ordinals, affirmations, and candidate names).
    public static func resolveClarificationChoice(
        userInput: String,
        pending: PendingClarification,
        catalog: [Item]
    ) -> (item: Item, quantity: Double, unit: String)? {
        let clean = userInput.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        if clean.isEmpty { return nil }

        // 1. Ordinal choices: "first", "1st", "pehla", "pehle wala", "1"
        if clean == "1" || clean == "1st" || clean == "first" || clean.contains("pehla") || clean.contains("pehle") {
            if let firstCandidate = pending.candidateNames.first,
               let catItem = catalog.first(where: { $0.name == firstCandidate }) {
                return (catItem, pending.quantity, pending.unit)
            }
        }

        // 2. Second choice: "second", "2nd", "dusra", "doosra", "2"
        if clean == "2" || clean == "2nd" || clean == "second" || clean.contains("dusra") || clean.contains("doosra") {
            if pending.candidateNames.count >= 2,
               let catItem = catalog.first(where: { $0.name == pending.candidateNames[1] }) {
                return (catItem, pending.quantity, pending.unit)
            }
        }

        // 3. Affirmation: "haan", "yes", "ok", "theek hai", "sure", "wahi"
        if clean == "yes" || clean == "haan" || clean == "ha" || clean == "ok" || clean == "theek hai" || clean == "wahi" {
            if let firstCandidate = pending.candidateNames.first,
               let catItem = catalog.first(where: { $0.name == firstCandidate }) {
                return (catItem, pending.quantity, pending.unit)
            }
        }

        // 4. Exact candidate name or candidate contains clean / clean contains candidate:
        // Priority 4a: Exact name match
        for candidateName in pending.candidateNames {
            if clean == candidateName.lowercased(),
               let catItem = catalog.first(where: { $0.name == candidateName }) {
                return (catItem, pending.quantity, pending.unit)
            }
        }

        // Priority 4b: Clean contains candidate name (e.g. "I want Sunflower Oil")
        for candidateName in pending.candidateNames {
            if clean.localizedCaseInsensitiveContains(candidateName),
               let catItem = catalog.first(where: { $0.name == candidateName }) {
                return (catItem, pending.quantity, pending.unit)
            }
        }

        // Priority 4c: Candidate name contains clean (e.g. user typed "sunflower" for "Sunflower Oil")
        for candidateName in pending.candidateNames {
            if candidateName.localizedCaseInsensitiveContains(clean),
               let catItem = catalog.first(where: { $0.name == candidateName }) {
                return (catItem, pending.quantity, pending.unit)
            }
        }

        // Priority 4d: Specific alias match (excluding the generic ambiguous query word like "oil" / "tel")
        let cleanQuery = pending.query.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        for candidateName in pending.candidateNames {
            if let catItem = catalog.first(where: { $0.name == candidateName }) {
                let candidateAliases = aliases(for: candidateName)
                for alias in candidateAliases {
                    let aliasLower = alias.lowercased()
                    // Disqualify alias if it is identical to or part of the ambiguous query (e.g. "oil", "tel")
                    if !cleanQuery.isEmpty && (aliasLower == cleanQuery || cleanQuery.contains(aliasLower) || aliasLower == "oil" || aliasLower == "tel") {
                        continue
                    }
                    if aliasLower.count >= 3 && (clean == aliasLower || clean.localizedCaseInsensitiveContains(aliasLower)) {
                        return (catItem, pending.quantity, pending.unit)
                    }
                }
            }
        }

        return nil
    }

    /// Extracts quantity and unit for a catalog item from user input text.
    /// Handles subunit scaling (grams -> kg, ml -> litre, pieces -> dozen) and colloquial terms.
    public static func extractQuantityAndUnit(
        for item: Item,
        from userInput: String
    ) -> (quantity: Double, unit: String) {
        let normalized = normalizeColloquials(userInput.lowercased())
        let itemAliases = aliases(for: item.name)

        // 1. Regex to find quantity and unit preceding or surrounding the item alias
        // e.g. "500g paneer", "500 g paneer", "0.5kg paneer", "3 eggs", "1 pkt maggi"
        for alias in itemAliases where alias.count >= 2 {
            let escapedAlias = NSRegularExpression.escapedPattern(for: alias)
            let pattern = "(\\d+(?:\\.\\d+)?)\\s*(kg|kilo|kilos|kilogram|g|gm|gram|grams|l|ltr|litre|litres|liter|liters|ml|packet|packets|pkt|pkts|piece|pieces|pc|pcs|dozen|doz)?\\s*(?:of\\s+)?(?:\\b|(?=[^a-z0-9]))" + escapedAlias
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let nsStr = normalized as NSString
                if let match = regex.firstMatch(in: normalized, options: [], range: NSRange(location: 0, length: nsStr.length)) {
                    let qtyStr = nsStr.substring(with: match.range(at: 1))
                    let rawQty = Double(qtyStr) ?? 1.0

                    var rawUnit = ""
                    if match.numberOfRanges > 2 && match.range(at: 2).location != NSNotFound {
                        rawUnit = nsStr.substring(with: match.range(at: 2)).lowercased()
                    }

                    return scaleUnit(quantity: rawQty, rawUnit: rawUnit, catalogUnitType: item.unitType)
                }
            }

            // Also check following pattern: alias + number + optional unit (e.g. "eggs 3", "maggi 1 packet")
            let followingPattern = escapedAlias + "\\s+(\\d+(?:\\.\\d+)?)\\s*(kg|kilo|kilos|kilogram|g|gm|gram|grams|l|ltr|litre|litres|liter|liters|ml|packet|packets|pkt|pkts|piece|pieces|pc|pcs|dozen|doz)?"
            if let regex = try? NSRegularExpression(pattern: followingPattern, options: .caseInsensitive) {
                let nsStr = normalized as NSString
                if let match = regex.firstMatch(in: normalized, options: [], range: NSRange(location: 0, length: nsStr.length)) {
                    let qtyStr = nsStr.substring(with: match.range(at: 1))
                    let rawQty = Double(qtyStr) ?? 1.0

                    var rawUnit = ""
                    if match.numberOfRanges > 2 && match.range(at: 2).location != NSNotFound {
                        rawUnit = nsStr.substring(with: match.range(at: 2)).lowercased()
                    }

                    return scaleUnit(quantity: rawQty, rawUnit: rawUnit, catalogUnitType: item.unitType)
                }
            }
        }

        return (1.0, item.unitType.shortLabel)
    }

    private static func scaleUnit(quantity: Double, rawUnit: String, catalogUnitType: UnitType) -> (Double, String) {
        if catalogUnitType == .kg {
            if rawUnit == "g" || rawUnit == "gm" || rawUnit == "gram" || rawUnit == "grams" {
                return (quantity / 1000.0, "kg")
            }
            return (quantity, "kg")
        }
        if catalogUnitType == .litre {
            if rawUnit == "ml" || rawUnit == "millilitre" {
                return (quantity / 1000.0, "L")
            }
            return (quantity, "L")
        }
        if catalogUnitType == .dozen {
            if rawUnit == "pc" || rawUnit == "piece" || rawUnit == "pcs" {
                return (quantity / 12.0, "dozen")
            }
            return (quantity, "dozen")
        }
        if catalogUnitType == .piece {
            return (quantity, "pc")
        }
        if catalogUnitType == .packet {
            return (quantity, "pkt")
        }
        return (quantity, catalogUnitType.shortLabel)
    }
}
