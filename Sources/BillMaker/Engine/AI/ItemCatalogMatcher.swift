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
        if lower.contains("mustard oil") {
            list.append(contentsOf: ["sarson tel", "sarson ka tel", "mustard oil", "sarson"])
        }
        if lower.contains("sunflower oil") {
            list.append(contentsOf: ["surajmukhi tel", "sunflower oil", "soorajmukhi"])
        }
        if lower.contains("rice") {
            list.append(contentsOf: ["chawal", "rice", "bhat"])
        }
        if lower.contains("atta") || lower.contains("flour") || lower.contains("wheat") {
            list.append(contentsOf: ["atta", "aata", "wheat flour", "gehun", "flour"])
        }
        if lower.contains("sugar") {
            list.append(contentsOf: ["cheeni", "chini", "shakkar", "sugar"])
        }
        if lower.contains("salt") {
            list.append(contentsOf: ["namak", "salt", "sendha namak"])
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
            list.append(contentsOf: ["maggi", "noodles", "maggie"])
        }
        if lower.contains("ginger") {
            list.append(contentsOf: ["adrak", "ginger"])
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
}
