import Foundation

/// Utility for building human-readable, transparent step-by-step reasoning logs.
///
/// Both the Local Parsing Engine and LLM Parsing Engine expose their thought process
/// so users and store owners can see exactly how item clauses were separated, how quantities
/// were normalized, how spelling errors were auto-corrected, and how prices were calculated.
public final class ThoughtLogger {
    private var steps: [String] = []

    public init() {}

    /// Logs a major high-level pipeline step.
    ///
    /// - Parameters:
    ///   - number: The step number (e.g. 1, 2, 3).
    ///   - title: A descriptive summary of what this pipeline step is doing.
    public func logStep(_ number: Int, title: String) {
        steps.append("Step \(number): \(title)")
    }

    /// Logs an item-level detail or intermediate transformation within a pipeline step.
    ///
    /// - Parameter detail: Detailed explanation of an auto-correction, unit conversion, or match.
    public func logDetail(_ detail: String) {
        steps.append("  ↳ \(detail)")
    }

    /// Compiles all recorded log steps into a single newline-delimited thought process string.
    ///
    /// - Returns: The complete formatted thought process.
    public func buildLog() -> String {
        return steps.joined(separator: "\n")
    }
}
