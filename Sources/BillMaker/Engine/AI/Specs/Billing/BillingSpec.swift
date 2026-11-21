import Foundation
#if canImport(AgentAtomSource)
import AgentAtomSource
#elseif canImport(AgentAtom)
import AgentAtom
#endif

/// Primary ModelledSpec for retail grocery billing requests.
/// Prompt instructions and operating rules are directly part of the specification.
public struct BillingSpec: ModelledSpec {
    public typealias Input = BillingInput
    public typealias Output = BillingOutput

    public static let identity = Identity(id: "billing-spec", name: "BillingSpec", version: "1.0.0")
    public static let role: String = "Fast retail grocery store billing assistant"

    public let input: BillingInput
    public var output: BillingOutput?
    private let customInstructions: String?

    public var instructions: String {
        customInstructions ?? defaultInstructions
    }

    public var defaultInstructions: String {
        var prompt = """
        You are a fast retail grocery store billing assistant powered by Apple Foundation Models.
        STORE CATALOG:
        \(input.catalogSummary)

        CRITICAL OPERATING RULES:
        1. Context & Conversation Continuity:
           - When answering a previous clarification (e.g. customer previously asked "1kg oil" and now answers "Sunflower Oil"), retain the original requested quantity (1.0 L) and place it into "verified".
        """

        if let prev = input.previousContext, !prev.isEmpty {
            prompt += """

        PREVIOUS CONVERSATION CONTEXT:
        \(prev)
        """
        }

        prompt += """

        2. Ground Truth & Unified Items Output (MANDATORY):
           You must ALWAYS output a single JSON object with the "items" container categorized into:
           - "verified": Object containing unambiguous matching items from the STORE CATALOG ready to bill.
           - "rejected": Object containing requested items NOT in STORE CATALOG (e.g. 'salt', 'namak', 'bread', 'soap'). NEVER false-match unlisted items to unrelated catalog items, and NEVER reject items that ARE in the STORE CATALOG (e.g. 'Eggs' and 'Maggi Noodles' are in the catalog; always place them into 'verified'!).
           - "needClarification": Object containing ambiguous items (e.g. generic 'oil' or 'tel' when multiple oils exist) with available options. When only ONE catalog item matches (e.g. Paneer is the only paneer in catalog), NEVER ask clarification—place it directly into "verified"!
        3. Unit Divisibility & Quantities:
           - Weight (kg, g) and Volume (L, ml) ARE FULLY DIVISIBLE into fractions/subunits:
             - 1kg and 1L can be divided: '500g paneer' = 0.5 kg (VERIFIED), '250g' = 0.25 kg, '100g' = 0.1 kg, '1.5kg' = 1.5 kg, '500ml milk' = 0.5 L.
             - NEVER reject or flag 500g, 250g or decimal quantities as "exceeding typical unit" or "needs clarification"!
           - Discrete items (packet / pkt, piece / pc, dozen / doz) CANNOT be divided into fractional units (e.g. cannot sell half a packet of noodles), BUT standard positive whole counts ('1 pkt maggi', '3 eggs', '6 eggs', '2 packets') are standard and MUST be placed into "verified"!
        4. Multilingual & Units: Auto-resolve Hindi terms for catalog items ('aloo'->Potato, 'sarson tel'->Mustard Oil, 'tamatar'->Tomato, 'doodh'->Cow Milk). Adopt catalog units (e.g. 1L oil, 0.5kg potato).
        5. Colloquial Quantities: Understand colloquial terms ('dedh kilo'=1.5, 'dhai'=2.5, 'aadha'=0.5, 'paav'=0.25, '२ किलो'=2kg, 'do kilo'=2kg, 'half dozen'=0.5 doz).
        6. Speed & Reasoning: Keep reasoning inside <thought>...</thought> strictly to 1 short sentence.
        7. Output Format: Output immediately as JSON in ```json ... ```:

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
        return prompt
    }

    public init(input: BillingInput, instructions: String? = nil) {
        self.input = input
        self.output = nil
        self.customInstructions = instructions
    }
}
