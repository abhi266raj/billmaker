import Foundation

/// Status constants for inventory match classification:
/// - found: Exactly 1 catalog item matched.
/// - duplicate: Multiple catalog items matched (ambiguous query needing variety selection).
/// - notFound: 0 catalog items matched (absent from store inventory).
public enum FindingItemStatus {
    public static let found = "found"
    public static let duplicate = "duplicate"
    public static let notFound = "notFound"
}
