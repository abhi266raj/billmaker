# BillMaker — Native Mac App with Local AI Agent & Retail Grocery Billing

**BillMaker** is a native macOS application designed for retail store billing powered by local on-device AI. It features an **Item Catalog & Context Manager** (Page 1) and an intelligent **Local Mac Agent Harness** (Page 2) that translates natural human speech and conversational orders into structured JSON, reconciles items against store inventory, and computes itemized bills in real-time.

---

## 🏗️ Architecture & How It Works

BillMaker runs an end-to-end **3-Stage Generic AI Pipeline** with zero hardcoded product dictionaries, zero local heuristic parsing fallbacks, and zero test simulation shortcuts. It runs on Apple Silicon using Apple Foundation Models (`/usr/bin/fm respond`) or native Apple Intelligence sessions.

### Pipeline Flow

```
                      [Customer Audio or Text Input]
                                     │
                                     ▼
        ┌────────────────────────────────────────────────────────┐
        │  Stage 1: Multilingual Entity & Quantity Extractor     │
        │  (ParsingPlanSpec)                                     │
        │  • Inputs: userQuery, languages: ["Hindi", "English"]  │
        │  • Transcribed speech & phonetic slips (aalu, sarso)   │
        │  • Linguistic numerals (aadha=0.5, dedh=1.5, darjan=12)│
        └────────────────────────────┬───────────────────────────┘
                                     │ ExtractedOrderItem[]
                                     ▼
        ┌────────────────────────────────────────────────────────┐
        │  Stage 2: Isolated Store Catalog Inventory Matcher     │
        │  (SingleItemFindingSpec)                               │
        │  • Item-by-item evaluation (prevents cross-talk)       │
        │  • Transliteration & code-switching resolution         │
        │  • Status: found (1 match) | duplicate | notFound      │
        └────────────────────────────┬───────────────────────────┘
                                     │ Matched Items
                                     ▼
        ┌────────────────────────────────────────────────────────┐
        │  Stage 3: Packaging & Feasibility Auditor              │
        │  (SingleItemReconciliationSpec)                        │
        │  • Indivisible packet validation (e.g. 0.5 pkt Maggi)  │
        │  • Subunit scaling (e.g. 500g @ ₹380/kg -> 0.5kg/₹190) │
        │  • Verified quantity and unit price preservation       │
        └────────────────────────────┬───────────────────────────┘
                                     │
                                     ▼
                 [Live Calculated Invoice / Clarification]
```

### Stage 1: Multilingual Entity & Quantity Extractor (`ParsingPlanSpec`)
- **Configurable Multilingual Input**: Accepts an array of languages (defaults to `["Hindi", "English"]`), dynamically informing the prompt without rigid language hardcoding.
- **Audio & Phonetic Artifact Resilience**: Voice dictation and transcribed speech often introduce phonetic slips, transliteration variations, regional accents, and typos (e.g., *"aalu"* for potato, *"sarso"* for mustard, *"ande"* for eggs).
- **Colloquial Numerals & Fractions**: Comprehends spoken fractions and regional quantity terms:
  - *aadha* / half = `0.5`
  - *pao* / quarter = `0.25`
  - *paun* / three-quarters = `0.75`
  - *sawa* = `1.25`
  - *dedh* = `1.5`
  - *dhai* = `2.5`
  - *darjan* / dozen = `12 pcs` (unit: `"pc"`)
- **Zero Item Hardcoding**: Generic extraction produces clean `[ExtractedOrderItem]` objects without assuming what is in the catalog.

### Stage 2: Store Catalog Inventory Matcher (`SingleItemFindingSpec`)
- **Isolated Item-by-Item Evaluation**: Small Language Models (SLMs) processing multi-item batches frequently suffer from cross-contamination, hallucinations, or dropping items. Evaluating candidate items item-by-item guarantees 100% item preservation.
- **Three-Way Classification**:
  - `found`: Exactly one unambiguous catalog match (e.g., *"sarso tel"* $\to$ *Mustard Oil*).
  - `duplicate`: Ambiguous or umbrella category matches (e.g., *"1L tel"* matches both *Mustard Oil* and *Sunflower Oil*). Prompts the user with one-click clarification options.
  - `notFound`: Requested item does not exist in the store catalog (e.g., *"surf excel"* when only groceries are stocked).

### Stage 3: Packaging & Feasibility Auditor (`SingleItemReconciliationSpec`)
- **Packaging Divisibility**: Distinguishes divisible loose items (`kg`, `litre`, `gram`, `ml`) from indivisible sealed packets or pieces (`packet`, `piece`, `can`, `box`).
- **Indivisible Clarification**: Requesting a fractional quantity of an indivisible item (e.g., *"aadha packet maggi"*) halts automated addition and prompts for clarification.
- **Subunit Conversion & Scaling**: Automatically reconciles customer requested subunits against catalog pricing base units:
  - Customer asks for *"500g paneer"* against a catalog item priced at `₹380.00 / kg`.
  - Reconciler scales quantity to `0.5 kg`, computing subtotal `0.5 * 380 = ₹190.00` rather than `500 * 380 = ₹190,000.00`.
  - Millilitres are scaled to litres (`500 ml` $\to$ `0.5 L`).

### Real-Time Diagnostics & Telemetry (`ParsingDiagnosticsLogger`)
- Captures full telemetry for every turn: input query, raw prompt, Apple Foundation Models raw LLM response, parsed JSON, pipeline timings, and any syntax or schema errors.
- Accessible directly from the macOS UI via **Parsing Diagnostics** inspector sheet.

---

## 🌟 Key Features

### 1. Item Catalog & Dynamic Context (Page 1)
- **Inventory Management**: Add, edit, remove, and search items with live persistence (`UserDefaults`).
- **Flexible Pricing Units**: Per kg, gram, piece, packet, litre, ml, or dozen.
- **Live Agent Context**: Any item or price change updated in the catalog is instantly available to the AI harness.

### 2. Local Mac Agent Harness (Page 2)
- **Natural Language Order Input**: Seamlessly mix English, Hindi, and Hinglish.
- **Conversational Clarification**: When umbrella terms are detected (e.g., *"oil"*), offers instant interactive option chips.
- **Visible Chain of Thought**: Displays model reasoning inside a collapsible card before the response.
- **Structured JSON Inspector**: View and copy raw JSON payloads of verified items, rejections, and clarifications.

### 3. Real-Time Billing & Invoice Harness
- **Live & Cumulative Accumulation**: Items accumulate continuously until reset via the **"Reset Bill"** button.
- **Configurable Duplicate Item Policy**: "Add to Quantity" or "Replace Quantity".
- **1-Click Conversational Undo**: Revert accidental additions instantly.
- **Computed Invoice**: Subtotals, total items, total weight in kg, total pieces, tax, and grand total.
- **Native Print & Clipboard**: Printable receipt format sheet and one-click clipboard copy.

### 4. Apple Foundation Models Engine & Zero External Dependencies
- **100% On-Device**: Powered natively by macOS Apple Intelligence (`/usr/bin/fm respond`).
- **Zero External Servers**: No Ollama, Python servers, Docker containers, or cloud API keys required.
- **Continuous Voice Dictation**: Apple Speech Recognition (`SFSpeechRecognizer`) supporting English (India/Hinglish), Hindi (`hi-IN`), US English, and UK English.

---

## 📁 Project Structure

```
billmaker/
├── BillMaker.xcodeproj                         # Xcode Project
├── project.yml                                 # XcodeGen specification
├── Package.swift                               # Swift Package Manager manifest
├── Sources/
│   └── BillMaker/
│       ├── App/
│       │   ├── BillMakerApp.swift              # App entry point
│       │   └── AppState.swift                  # Observable app state & bill lifecycle
│       ├── AI/
│       │   ├── AgentAtomBillingEngine.swift    # 3-Stage pipeline orchestrator
│       │   ├── AgentAtomSession.swift          # /usr/bin/fm respond runner
│       │   ├── BillingOutput.swift             # JSON & thought extractor
│       │   ├── CatalogItemData.swift           # Codable catalog projection
│       │   ├── ParsingDiagnosticsLogger.swift  # Turn-by-turn telemetry logger
│       │   └── Specs/                          # Spec inputs, outputs, instructions
│       │       ├── Parsing/
│       │       │   ├── ParsingPlanInput.swift  # Query & languages array
│       │       │   ├── ParsingPlanSpec.swift   # Generic entity extraction spec
│       │       │   └── ParsingPlanOutput.swift # Resilient Codable output
│       │       ├── FindingItem/
│       │       │   ├── FindingItemInput.swift  # Extracted items + catalog
│       │       │   ├── FindingItemSpec.swift   # Single-item catalog matcher
│       │       │   ├── FindingItemStatus.swift # found | duplicate | notFound
│       │       │   └── FindingItemOutput.swift # Matched catalog items
│       │       └── Reconciliation/
│       │           ├── ReconciliationInput.swift
│       │           ├── ReconciliationSpec.swift# Single-item feasibility auditor
│       │           ├── QuantityValidity.swift  # valid | invalid | requiresClarification
│       │           └── ReconciliationOutput.swift
│       ├── Models/
│       │   ├── Item.swift                      # Catalog item definition
│       │   ├── Bill.swift                      # BilledItem & BillSummary
│       │   ├── AgentMessage.swift              # Messages & chat state
│       │   └── AppSettings.swift               # Preferences & voice settings
│       ├── Services/
│       │   ├── Billing/
│       │   │   └── BillCalculator.swift        # Subunits, taxes, and totals
│       │   ├── Printing/
│       │   │   └── ReceiptService.swift        # Native macOS print formatter
│       │   ├── Speech/
│       │   │   └── SpeechRecognitionService.swift # Apple SFSpeechRecognizer
│       │   └── Storage/
│       │       ├── CatalogStorageService.swift
│       │       └── SettingsStorageService.swift
│       ├── Views/
│       │   ├── MainView.swift                  # NavigationSplitView sidebar
│       │   ├── Catalog/                        # Inventory management sheets
│       │   └── Harness/                        # Chat, invoice, diagnostics views
│       └── Resources/
│           ├── DefaultCatalog.json             # Pre-loaded grocery catalog
│           └── Info.plist
└── Tests/
    └── BillMakerTests/
        ├── BillCalculationTests.swift          # Unit tests (subunits, tax, undo)
        ├── SpeechRecognitionTests.swift        # Voice settings & audio configs
        └── LLMParsingTests.swift               # Live Apple Foundation Model tests
```

---

## 🚀 How to Run & Verify

### Option 1: Open in Xcode
1. Open the project:
   ```bash
   open BillMaker.xcodeproj
   ```
2. Select target **BillMaker** and press `Cmd + R` (Run).

### Option 2: Command Line (SPM)
- **Build**:
  ```bash
  swift build
  ```
- **Run Unit Tests**:
  ```bash
  swift test --filter BillCalculationTests
  swift test --filter SpeechRecognitionTests
  ```
- **Run Live Apple Foundation Model Tests**:
  ```bash
  swift test --filter LLMParsingTests/testThreeStepPipeline
  swift test --filter LLMParsingTests/testEggCatalogLookupAndQuantityVariations
  ```
- **Build with xcodebuild**:
  ```bash
  xcodebuild -scheme BillMakerTests -destination 'platform=macOS' test -only-testing:BillMakerTests/BillCalculationTests
  ```
