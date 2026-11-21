# BillMaker — Mac App with Local AI Agent & Item Catalog Harness

**BillMaker** is a native macOS application designed for retail store billing and local AI agent experimentation. It features a dynamic **Item Catalog & Context Manager** (Page 1) and an intelligent **Local Mac Agent Harness** (Page 2) that translates natural human speech and orders into structured JSON and computes itemized bills in real-time.

---

## 🌟 Key Features

### 1. Page 1: Item Catalog & Dynamic Context
- **Inventory Management**: Add, edit, remove, and search items with live persistence (`UserDefaults`).
- **Colloquial Aliases / Other Names**: Supports multiple colloquial, regional, and Hindi names for items (e.g. `Potato` with aliases `["Aloo", "Batata", "Aalu", "Potatoes"]`, `Cow Milk` with `["Doodh", "Dudh", "Milk"]`).
- **Flexible Pricing Units**: Specify how each item is sold:
  - Per Kilogram (`kg`)
  - Per Gram (`gram` / `g`)
  - Per Piece / Unit (`piece`)
  - Per Packet (`packet`)
  - Per Litre (`litre` / `L`)
  - Per Millilitre (`ml`)
  - Per Dozen (`dozen` / 12 pcs)
- **Live Agent Context**: Any item or price change updated here is instantly available as context to the AI harness.

### 2. Page 2: Local Mac Agent Harness
- **Natural Language Order Input**: Enter orders naturally in Hindi, Hinglish, or English:
  - *"dedh kilo aalu aur 1L sarso tel"*
  - *"500g paneer, 3 eggs, aur 1 pkt maggi"*
  - *"dedh kilo aalu aur aadha kilo tamatar"*
  - *"1 dozen kela aur 2kg seb"*
- **Spelling Mistake Auto-Correction (Levenshtein Distance)**:
  - Automatically identifies and repairs typos (e.g. *"potaoe"* → *Potato*, *"panir"* → *Paneer*, *"onoin"* → *Onion*, *"tamatr"* → *Tamatar*).
  - Directly accepts corrected items into the live bill without blocking the customer.
  - Explicitly states the auto-correction in the output response.
  - Provides a 1-click **Undo** button in both the chat bubble and the invoice header to quickly revert if desired.
- **Human-like To-and-Fro Clarification**:
  - Kept to at most 1 concise sentence if strictly needed.
  - Multi-item orders are never blocked by single ambiguities.
- **Visible Thought Process**:
  - The agent explicitly displays its step-by-step reasoning (scratchpad / chain of thought) inside a collapsible card before responding.
- **Structured JSON Output**:
  - The AI formats its internal findings into clean JSON containing item IDs, matched aliases, normalized quantities, units, and unit prices.
  - Users can view and copy the raw JSON via the built-in **JSON Inspector**.

### 3. Real-Time Billing & Invoice Harness
- **Live & Cumulative**: Items accumulate continuously until reset via the UX **"Reset Bill"** button.
- **Duplicate Item Policy**: Choose between **"Add to Quantity"** (e.g., 1kg + 1kg = 2kg) or **"Replace Quantity"** when an item is re-entered.
- **1-Click Undo**: Revert any accidental addition or auto-correction back to the previous bill state.
- Computes:
  - Subtotal per item
  - Total items count
  - Total weight in Kilograms (e.g., `2.00 kg`)
  - Total pieces
  - Tax (configurable percentage) & Grand Total
- Features **Print Invoice** (native macOS print sheet) and **Copy Receipt to Clipboard**.

### 4. Apple Foundation Models Engine & Zero External Dependencies
- **100% On-Device Apple Foundation Models**: Powered natively by macOS Apple Intelligence (`FoundationModels` framework, `SystemLanguageModel`, and `LanguageModelSession`).
- **No External Servers or API Keys**: Zero dependencies on Ollama, Python, or external cloud servers. Executes privately and rapidly on Apple Silicon.
- **Continuous Voice Dictation**: Integrated Apple Speech Recognition (`SFSpeechRecognizer`) supporting English (India/Hinglish), Hindi (`hi-IN`), US English, and UK English.
- **Xcode & VS Code Ready**: Open with `BillMaker.xcworkspace`, `BillMaker.xcodeproj`, or `BillMaker.code-workspace`.

---

## 📁 Project Structure

```
billmaker/
├── BillMaker.xcodeproj             # Xcode Project (open with Xcode)
├── project.yml                     # XcodeGen configuration
├── Package.swift                   # Swift Package Manager (for VS Code & CLI)
├── .vscode/
│   ├── tasks.json                  # VS Code build, test, and run tasks
│   ├── launch.json                 # VS Code LLDB debug launcher
│   └── settings.json               # VS Code Swift settings
├── Sources/
│   └── BillMaker/
│       ├── App/
│       │   ├── BillMakerApp.swift  # App entry point
│       │   └── AppState.swift      # Global observable state & persistence
│       ├── Models/
│       │   ├── Item.swift          # Item definition, unit types, aliases
│       │   ├── Bill.swift          # BilledItem & BillSummary with weight
│       │   ├── AgentMessage.swift  # Messages, thoughts, and JSON schema
│       │   └── AppSettings.swift   # Engine selection & preferences
│       ├── Engine/
│       │   ├── AgentEngineProtocol.swift
│       │   ├── NativeSwiftAgentEngine.swift # Built-in intelligent Swift engine
│       │   ├── LocalLLMAgentEngine.swift    # Ollama / LM Studio connector
│       │   └── BillCalculator.swift         # Calculates subtotals, weight, totals
│       ├── Views/
│       │   ├── MainView.swift               # NavigationSplitView sidebar
│       │   ├── Catalog/
│       │   │   ├── CatalogView.swift        # Table, search, filters
│       │   │   └── ItemEditorSheet.swift    # Add / edit modal
│       │   ├── Harness/
│       │   │   ├── AgentHarnessView.swift   # Conversational harness & prompt chips
│       │   │   ├── ChatMessageBubble.swift  # Bubble with thought process & JSON view
│       │   │   ├── LiveInvoiceView.swift    # Real-time calculated bill receipt
│       │   │   └── JSONInspectorView.swift  # JSON inspection sheet
│       │   └── Settings/
│       │       └── SettingsView.swift       # Preferences & local LLM URL
│       └── Resources/
│           ├── DefaultCatalog.json          # Pre-loaded grocery catalog
│           └── Info.plist
└── Tests/
    └── BillMakerTests/
        └── BillCalculationTests.swift       # Unit test suite
```

---

## 🚀 How to Run

### Option 1: Open in Xcode (`BillMaker.xcodeproj`)
1. Open the project in Xcode:
   ```bash
   open BillMaker.xcodeproj
   ```
2. Select target **BillMaker** and press `Cmd + R` (Run).

### Option 2: Run via Terminal / VS Code
- **Build**:
  ```bash
  swift build
  ```
- **Run**:
  ```bash
  swift run BillMaker
  ```
- **Run Tests**:
  ```bash
  swift test
  ```
- **Build with xcodebuild**:
  ```bash
  xcodebuild -project BillMaker.xcodeproj -scheme BillMaker -configuration Debug build
  ```
