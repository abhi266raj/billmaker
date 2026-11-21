import Foundation

/// Constructs the prompt, dynamic catalog context, and message payload passed to the Server AI.
///
/// Everything is handled by the AI:
/// - Parsing multi-item orders without punctuation
/// - Spelling error & typo fixing
/// - Colloquial Hindi & English measurements
/// - Unit mismatch checks
/// - Conversational questions
public struct LLMPromptBuilder {
    /// Builds the system prompt string containing the active store catalog and operational rules.
    public static func buildSystemPrompt(catalog: [Item], currencySymbol: String) -> String {
        let catalogSummary: String = catalog.map { item in
            "- ID: \(item.id.uuidString) | Name: \(item.name) | Aliases: [\(item.aliases.joined(separator: ", "))] | Unit: \(item.unitType.rawValue) | Price: \(currencySymbol)\(item.pricePerUnit)"
        }.joined(separator: "\n")

        return """
        You are an intelligent, fast retail & grocery store AI billing assistant.
        You have direct access to the store's inventory catalog below.

        STORE INVENTORY CATALOG:
        \(catalogSummary)

        CRITICAL OPERATING RULES:
        1. Context Isolation: Evaluate ONLY the user's current request. Do not include past completed orders.
        2. Spelling Mistakes & Typos: Automatically fix typos (e.g. 'potaoe' -> Potato, 'panir' -> Paneer, 'tamatr' -> Tomato) and directly accept them.
        3. Colloquial Quantities & Hindi: Understand both English and Hindi colloquial expressions ('dedh kilo' = 1.5 kg, 'dhai' = 2.5, 'aadha kilo' = 0.5 kg, 'ek paav' = 0.25 kg, '२ किलो' = 2 kg, 'दो किलो' = 2 kg, 'half dozen' = 0.5 dozen).
        4. Multi-Item Extraction: When a user gives multiple items in one order (e.g. "2kg potato 1kg tomato 500g paneer"), extract ALL items into the items array. Do not interrupt with unnecessary questions.
        5. Unit Mismatch Correction: If a user specifies litres for an item sold in kg (or kg for an item sold in litres), use the catalog's unit and note it in the response message.
        6. Ambiguity: If an item is truly ambiguous (e.g. "2 kg tel" when multiple oils exist), ask back which one in ONE short sentence ("Which oil would you like? We have Mustard Oil or Sunflower Oil.") and set status to "needs_clarification".
        7. Reasoning: ALWAYS output your step-by-step reasoning inside <thought>...</thought> tags before your response.
        8. Structured JSON: ALWAYS output clean JSON matching the following schema inside a ```json ... ``` code fence:

        ```json
        {
          "status": "ready" | "needs_clarification",
          "message": "Concise 1-sentence response to customer",
          "thought": "Brief reasoning summary",
          "items": [
            {
              "itemId": "uuid-or-null",
              "itemName": "Catalog Item Name",
              "matchedAlias": "what user called it",
              "quantity": 1.5,
              "unit": "kg",
              "unitPrice": 30.0,
              "wasAutoCorrected": false,
              "wasUnitCorrected": false
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
