import Foundation
#if canImport(AgentAtomSource)
import AgentAtomSource
#elseif canImport(AgentAtom)
import AgentAtom
#endif

/// ModelledSpec for verifying whether user input constitutes a valid clarification response
/// or whether it should fall back to the initial billing state.
public struct ClarificationSpec: ModelledSpec {
    public typealias Input = ClarificationInput
    public typealias Output = ClarificationOutput

    public static let identity = Identity(id: "clarification-spec", name: "ClarificationSpec", version: "1.0.0")
    public static let role: String = "Guardian verifier for ambiguous grocery item clarifications"

    public let input: ClarificationInput
    public var output: ClarificationOutput?
    public var instructions: String

    public init(input: ClarificationInput, instructions: String) {
        self.input = input
        self.instructions = instructions
    }
}
