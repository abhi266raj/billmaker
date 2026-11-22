import Foundation
#if canImport(AgentAtomSource)
import AgentAtomSource
#elseif canImport(AgentAtom)
import AgentAtom
#endif

/// Evaluates a single extracted order item against the full store catalog.
public struct SingleItemFindingSpec: ModelledSpec {
    public typealias Input = SingleItemFindingInput
    public typealias Output = ItemFindingResult

    public static let identity = Identity(id: "single-item-finding-spec", name: "SingleItemFindingSpec", version: "1.0.0")
    public static let role: String = "Single-item store inventory matcher and ambiguity resolver"

    public let input: SingleItemFindingInput
    public var output: ItemFindingResult?

    public var instructions: String {
        """
        You are an intelligent store catalog lookup assistant evaluating ONE requested grocery item against the store inventory.
        Search the store `catalog` for products that match the requested `item.name`.

        CRITICAL OPERATING GUIDELINES:
        1. Match Identification:
           - Understand that `item.name` may be in English or Romanized Hindi/Hinglish (e.g. 'maggi' -> 'Maggi Noodles', 'ande'/'egg' -> 'Eggs', 'aalu' -> 'Potato', 'tamatar' -> 'Tomato', 'sarso tel' -> 'Mustard Oil', 'doodh' -> 'Milk', 'chawal' -> 'Basmati Rice', 'atta' -> 'Atta (Wheat Flour)').
           - Search `catalog` for all products matching `item.name`.

        2. Ambiguity & Multiple Matches (CRITICAL):
           - If `item.name` is a general category that matches MULTIPLE distinct products in `catalog` (e.g. 'oil' when both 'Mustard Oil' and 'Sunflower Oil' are in the catalog, or 'milk' when both 'Cow Milk' and 'Packet Milk' are in the catalog):
             * You MUST set "status": "duplicate".
             * You MUST put ALL matching products into `matchedCatalogItems`. NEVER pick just one product!

        3. Single Match:
           - If and only if exactly ONE product in `catalog` matches:
             * Set "status": "found".
             * Put only that single product into `matchedCatalogItems`.

        4. Absent Product:
           - If no product in `catalog` matches:
             * Set "status": "notFound".
             * `matchedCatalogItems` = [].

        5. Output Format:
           - Return ONLY a valid JSON object:
             {"status": "found|duplicate|notFound", "matchedCatalogItems": [...], "note": "..."}
        """
    }

    public init(input: SingleItemFindingInput) {
        self.input = input
        self.output = nil
    }
}

/// Evaluates a list of extracted items one-by-one against the store catalog.
public struct FindingItemPlanSpec: ModelledSpec {
    public typealias Input = FindingItemPlanInput
    public typealias Output = FindingItemPlanOutput

    public static let identity = Identity(id: "finding-item-plan-spec", name: "FindingItemPlanSpec", version: "1.0.0")
    public static let role: String = "Store catalog inventory matcher and ambiguity resolver"

    public let input: FindingItemPlanInput
    public var output: FindingItemPlanOutput?

    public var instructions: String {
        """
        You are a store inventory catalog matcher.
        For EACH item in `extractedItems`, search the full `catalog` and create an `ItemFindingResult`:
        1. 'found': Exactly ONE product matches phonetically or semantically. `matchedCatalogItems` contains ONLY that 1 product.
        2. 'duplicate': Ambiguous item matching MULTIPLE catalog products (e.g. 'oil' matching 'Mustard Oil' and 'Sunflower Oil'). `matchedCatalogItems` contains ALL matching candidate products.
        3. 'notFound': Item is not present anywhere in the catalog. `matchedCatalogItems` is empty [].

        Ensure EVERY item from `extractedItems` is evaluated and present in `results`.
        """
    }

    public init(input: FindingItemPlanInput) {
        self.input = input
        self.output = nil
    }
}
