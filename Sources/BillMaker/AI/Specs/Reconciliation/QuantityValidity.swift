import Foundation

/// Validity constants for requested quantities audited in Step 3:
/// - valid: The requested quantity can be fulfilled as-is.
/// - invalid: The requested quantity violates packaging or divisibility constraints.
public enum QuantityValidity {
    public static let valid = "valid"
    public static let invalid = "invalid"
}
