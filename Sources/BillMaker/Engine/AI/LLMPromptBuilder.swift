import Foundation

/// Constructs the prompt, dynamic catalog context, and message payload passed to Apple Foundation Models.
public struct LLMPromptBuilder {
    /// Builds an ultra-compact system prompt containing the active store catalog and strict operating rules.
    public static func buildSystemPrompt(catalog: [Item], currencySymbol: String) -> String {
        let catalogSummary: String = catalog.map { item in
            "- \(item.name): \(currencySymbol)\(item.pricePerUnit)/\(item.unitType.shortLabel)"
        }.joined(separator: "\n")

        return """
        You are a fast retail grocery store billing assistant powered by Apple Foundation Models.
        STORE CATALOG:
        \(catalogSummary)

        CRITICAL OPERATING RULES:
        1. Context Isolation: Process ONLY the customer's current request.
        2. Strict Catalog Matching: Match ONLY to items listed in the STORE CATALOG. NEVER ask about premium options, brands, qualities, or items not listed in the catalog.
        3. Bare Minimum & Instant Billing: If an item matches a catalog item, immediately bill it with status "ready". Do NOT ask clarifying questions unless the item is completely absent from the store catalog.
        4. Multilingual & Typos: Auto-resolve Hindi/Hinglish terms ('aloo'->Potato, 'sarson tel'->Mustard Oil, 'tamatar'->Tomato, 'doodh'->Cow Milk, 'anda'->Eggs, 'kela'->Banana, 'cheeni'->Sugar) directly.
        5. Colloquial Quantities: Understand numbers & units ('dedh kilo'=1.5kg, 'dhai'=2.5, 'aadha'=0.5, 'paav'=0.25, '२ किलो'=2kg, 'do kilo'=2kg, 'half dozen'=0.5 doz).
        6. Speed & Reasoning: Keep reasoning inside <thought>...</thought> strictly to 1 short sentence.
        7. Output: Output immediately as JSON in ```json ... ```:

        ```json
        {
          "status": "ready" | "needs_clarification",
          "message": "Concise 1-sentence confirmation",
          "thought": "Brief 1-sentence reasoning",
          "items": [
            {
              "itemName": "Exact Catalog Name",
              "quantity": 1.5,
              "unit": "kg",
              "unitPrice": 30.0
            }
          ]
        }
        ```
        """
    }

    /// Formats the chat message array for language model context.
    public static func buildChatMessages(
        userInput: String,
        catalog: [Item],
        currencySymbol: String
    ) -> [[String: String]] {
        let systemPrompt = buildSystemPrompt(catalog: catalog, currencySymbol: currencySymbol)
        return [
            ["role": "system", "content": systemPrompt],
            ["role": "user", "content": userInput]
        ]
    }
}
