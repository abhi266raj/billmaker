import Foundation
#if canImport(AgentAtomSource)
import AgentAtomSource
#elseif canImport(AgentAtom)
import AgentAtom
#endif

/// AgentAtom ModelledSpec for Step 1: Speech-transcription and multilingual grocery entity & quantity extractor.
/// Scans customer text/transcription and extracts EVERY requested item into structured ExtractedOrderItem records.
public struct ParsingPlanSpec: ModelledSpec {
    public typealias Input = ParsingPlanInput
    public typealias Output = ParsingPlanOutput

    public static let identity = Identity(id: "parsing-plan-spec", name: "ParsingPlanSpec", version: "1.0.0")
    public static let role: String = "Multilingual retail grocery entity and quantity extractor"

    public let input: ParsingPlanInput
    public var output: ParsingPlanOutput?

    public var instructions: String {
        let languageList = input.languages.isEmpty ? "Hindi, English" : input.languages.joined(separator: ", ")
        return """
        You are an expert multilingual entity and quantity extractor for retail grocery orders.
        Target Languages: \(languageList) (including Romanized transliterations, Hinglish in Latin script, and code-switching).
        Scan the customer query and extract EVERY requested grocery item into an array of ExtractedOrderItem records with keys: 'name' (String), 'quantity' (Double), 'unit' (String).

        CRITICAL OPERATING GUIDELINES:
        1. Transcribed Speech & Multilingual Vocabulary :
           - The input text may be transcribed from live audio or speech recognition with phonetic slips, transliteration variations, regional accents, typos, and colloquial phrasing.
           - Understand colloquial grocery items in English or Romanized Hindi across \(languageList) (e.g. 'eggs'/'ande', 'potato'/'aalu', 'tomato'/'tamatar', 'oil'/'tel', 'mustard oil'/'sarso tel', 'milk'/'doodh', 'paneer', 'flour'/'atta', 'rice'/'chawal', 'tea'/'chai', 'maggi').
           - Accurately extract the grocery entity name without dropping letters (e.g. 'eggs' or 'ande', never truncate).
           - Faithfully extract the exact products requested. NEVER substitute or hallucinate unrelated items.

        2. Colloquial Quantities & Linguistic Numerals:
           - Convert dozen / darjan to individual discrete pieces:
             * 1 dozen / ek darjan = 12 pcs (quantity: 12.0, unit: "pc")
             * half dozen / aadha darjan = 6 pcs (quantity: 6.0, unit: "pc")
           - Understand spoken fractions:
             * "aadha" / "half" = 0.5
             * "dedh" / "derh" = 1.5
             * "dhai" / "dhaai" = 2.5
             * "pao" / "paav" = 0.25 (or 250g)
             * "sawa" = 1.25
             * "paun" / "pona" = 0.75
           - Accurately separate the numeric quantity and standard retail unit (e.g. kg, g, L, ml, pkt, pc).
           - Normalize standard volume units appropriately (e.g. 1000 ml as 1.0 L or 1000 ml).

        3. Code-Switching & Conversational Hinglish:
           - Customers frequently mix Hindi and English.
           - Ignore conversational filler words and pleasantries.
           - NEVER drop or omit any item. If multiple items are requested, ALL items MUST appear in `extractedItems`.
        """
    }

    public init(input: ParsingPlanInput) {
        self.input = input
        self.output = nil
    }
}
