import Foundation
#if canImport(AgentAtomSource)
import AgentAtomSource
#elseif canImport(AgentAtom)
import AgentAtom
#endif

/// ModelledSpec for verifying whether user input constitutes a valid clarification response
/// or whether it should fall back to the initial billing state.
/// Instructions are directly embedded as part of the specification.
public struct ClarificationSpec: ModelledSpec {
    public typealias Input = ClarificationInput
    public typealias Output = ClarificationOutput

    public static let identity = Identity(id: "clarification-spec", name: "ClarificationSpec", version: "1.0.0")
    public static let role: String = "Guardian verifier for ambiguous grocery item clarifications"

    public let input: ClarificationInput
    public var output: ClarificationOutput?
    private let customInstructions: String?

    public var instructions: String {
        customInstructions ?? defaultInstructions
    }

    public var defaultInstructions: String {
        """
        You are verifying whether the customer's response resolves a pending clarification.
        Pending query: '\(input.pendingQuery)' (Qty: \(input.pendingQuantity) \(input.pendingUnit))
        Available options: \(input.candidateOptions.joined(separator: ", "))

        Instructions:
        1. If the customer clearly selected one of the available options (by name, number, or description), set isRealClarification = true, selectedItemName to the option, and fallbackToInitial = false.
        2. If the customer asked for something completely different or canceled, set isRealClarification = false and fallbackToInitial = true.
        Return output matching ClarificationOutput.
        """
    }

    public init(input: ClarificationInput, instructions: String? = nil) {
        self.input = input
        self.output = nil
        self.customInstructions = instructions
    }
}
