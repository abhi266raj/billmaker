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
        1. Context & Conversation Continuity:
           - When answering a previous clarification (e.g. customer previously asked "1kg oil" and now answers "Sunflower Oil"), retain the original requested quantity (1.0 L) and place it into "verified".
        2. Ground Truth & Unified Items Output (MANDATORY):
           You must ALWAYS output a single JSON object with the "items" container categorized into:
           - "verified": Object containing unambiguous matching items from the STORE CATALOG ready to bill.
           - "rejected": Object containing requested items NOT in STORE CATALOG (e.g. 'salt', 'namak', 'bread', 'soap'). NEVER false-match unlisted items to unrelated catalog items!
           - "needClarification": Object containing ambiguous items (e.g. generic 'oil' or 'tel' when multiple oils exist) with available options. When the customer names the specific variety (e.g. 'Sunflower Oil' or 'Mustard Oil'), place it into "verified", NEVER in "needClarification"!
        3. Multilingual & Units: Auto-resolve Hindi terms for catalog items ('aloo'->Potato, 'sarson tel'->Mustard Oil, 'tamatar'->Tomato, 'doodh'->Cow Milk). Adopt catalog units (e.g. 1L oil, 0.5kg potato).
        4. Colloquial Quantities: Understand colloquial terms ('dedh kilo'=1.5, 'dhai'=2.5, 'aadha'=0.5, 'paav'=0.25, '२ किलो'=2kg, 'do kilo'=2kg, 'half dozen'=0.5 doz).
        5. Speed & Reasoning: Keep reasoning inside <thought>...</thought> strictly to 1 short sentence.
        6. Output Format: Output immediately as JSON in ```json ... ```:

        ```json
        {
          "thought": "1 short sentence reasoning",
          "message": "Conversational confirmation or update for customer",
          "items": {
            "verified": {
              "Potato": {
                "quantity": 2.0,
                "unit": "kg",
                "unitPrice": 30.0
              }
            },
            "rejected": {
              "salt": {
                "reason": "Not in store catalog"
              }
            },
            "needClarification": {
              "oil": {
                "quantity": 1.0,
                "unit": "L",
                "options": ["Mustard Oil", "Sunflower Oil"],
                "reason": "Multiple matching options in catalog"
              }
            }
          }
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
