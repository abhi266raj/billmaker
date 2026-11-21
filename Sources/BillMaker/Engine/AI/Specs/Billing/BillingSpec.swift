import Foundation
#if canImport(AgentAtomSource)
import AgentAtomSource
#elseif canImport(AgentAtom)
import AgentAtom
#endif

/// Primary ModelledSpec for initial retail grocery billing requests.
public struct BillingSpec: ModelledSpec {
    public typealias Input = BillingInput
    public typealias Output = BillingOutput

    public static let identity = Identity(id: "billing-spec", name: "BillingSpec", version: "1.0.0")
    public static let role: String = "Fast retail grocery store billing assistant"

    public let input: BillingInput
    public var output: BillingOutput?
    public var instructions: String

    public init(input: BillingInput, instructions: String) {
        self.input = input
        self.instructions = instructions
    }
}
