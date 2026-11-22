import Foundation
#if canImport(AgentAtomSource)
import AgentAtomSource
#elseif canImport(AgentAtom)
import AgentAtom
#endif

/// Evaluates quantity feasibility and packaging divisibility for ONE found catalog item.
public struct SingleItemReconciliationSpec: ModelledSpec {
    public typealias Input = FoundItemForReconciliation
    public typealias Output = ReconciledQuantityResult

    public static let identity = Identity(id: "single-item-reconciliation-spec", name: "SingleItemReconciliationSpec", version: "1.0.0")
    public static let role: String = "Single-item grocery quantity feasibility and packaging divisibility auditor"

    public let input: FoundItemForReconciliation
    public var output: ReconciledQuantityResult?

    public var instructions: String {
        """
        You are a retail grocery store inventory quantity and packaging auditor.
        Evaluate the requested quantity of ONE found item against its packaging type:

        CRITICAL OPERATING GUIDELINES:
        1. Loose Items (`catalogItem.type == "loose"`):
           - Loose items are sold by weight or volume. ANY requested quantity is ALWAYS valid.
           - Convert subunits to `catalogItem.unit`:
             * Grams to kg: 500g -> verifiedQuantity = 0.5, verifiedUnit = "kg" (250g -> 0.25, verifiedUnit = "kg").
             * Millilitres to L: 500ml -> verifiedQuantity = 0.5, verifiedUnit = "L" (1000ml -> 1.0, verifiedUnit = "L").
             * Otherwise: verifiedQuantity = requestedQuantity, verifiedUnit = catalogItem.unit.
           - Set validity = "valid", unitPrice = catalogItem.price.

        2. Packet Items (`catalogItem.type == "packet"`):
           - Factory sealed packets cannot be cut open or sold in fractions.
           - Whole number of packets (1, 2, 3) -> validity = "valid", verifiedQuantity = requestedQuantity, verifiedUnit = catalogItem.unit, unitPrice = catalogItem.price.
           - Fractional packet (like 0.5 packet, or loose weight for a packet product) -> validity = "invalid":
             * validity = "invalid"
             * invalidReason = "Packet items cannot be opened or sold in fractional weight."
             * alternativeQuantity = 1.0 (or nearest discrete whole packet count), alternativeUnit = catalogItem.unit
             * unitPrice = catalogItem.price
        """
    }

    public init(input: FoundItemForReconciliation) {
        self.input = input
        self.output = nil
    }
}

/// AgentAtom ModelledSpec for Step 3: Quantity Feasibility & Packaging Divisibility Audit on FOUND items ONLY.
public struct ReconciliationPlanSpec: ModelledSpec {
    public typealias Input = ReconciliationPlanInput
    public typealias Output = ReconciliationPlanOutput

    public static let identity = Identity(id: "reconciliation-plan-spec", name: "ReconciliationPlanSpec", version: "1.0.0")
    public static let role: String = "Found item quantity feasibility and packaging divisibility auditor"

    public let input: ReconciliationPlanInput
    public var output: ReconciliationPlanOutput?

    public var instructions: String {
        """
        You are a retail grocery store inventory quantity and packaging auditor.
        You receive ONLY items that were successfully FOUND in the store catalog.
        Your sole task is to verify whether each requested quantity is VALID or INVALID:

        CRITICAL OPERATING GUIDELINES:
        1. When catalogItem.type is "loose" (e.g. fresh vegetables, fruits, loose grains, loose oil):
           - Loose items are sold by weight or volume. ANY requested quantity (such as 0.25, 0.5, 1.5, 2.0 kg or litres) is ALWAYS VALID.
           - ALWAYS set: validity = "valid", verifiedQuantity = requestedQuantity, verifiedUnit = catalogItem.unit, unitPrice = catalogItem.price.

        2. When catalogItem.type is "packet" (e.g. sealed noodles, biscuits, tea boxes):
           - Factory sealed packets cannot be cut open or sold in fractions.
           - Whole number of packets (1, 2, 3) -> validity = "valid", verifiedQuantity = requestedQuantity, verifiedUnit = catalogItem.unit, unitPrice = catalogItem.price.
           - Fractional packet (like 0.5 packet) -> validity = "invalid", invalidReason = "Packet cannot be split", alternativeQuantity = 1.0, alternativeUnit = catalogItem.unit.

        3. Completeness:
           - For EACH item in `foundItems`, output exactly one entry in `reconciledItems`.
           - NEVER omit any item.
        """
    }

    public init(input: ReconciliationPlanInput) {
        self.input = input
        self.output = nil
    }
}
