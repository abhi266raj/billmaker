import SwiftUI

public struct ItemEditorSheet: View {
    @Environment(\.dismiss) private var dismiss

    let existingItem: Item?
    let onSave: (Item) -> Void

    @State private var name: String = ""
    @State private var unitType: UnitType = .kg
    @State private var pricePerUnit: Double = 0.0
    @State private var category: String = "Vegetables"
    @State private var notes: String = ""
    @State private var inStock: Bool = true

    private let standardCategories = ["Vegetables", "Fruits", "Dairy", "Oils & Spices", "Pantry & Grains", "Packaged Food", "Poultry & Eggs", "Beverages", "General"]

    public init(existingItem: Item? = nil, onSave: @escaping (Item) -> Void) {
        self.existingItem = existingItem
        self.onSave = onSave
    }

    public var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Basic Information")) {
                    TextField("Item Name (e.g. Potato, Cow Milk)", text: $name)

                    Picker("Category", selection: $category) {
                        ForEach(standardCategories, id: \.self) { cat in
                            Text(cat).tag(cat)
                        }
                    }
                }

                Section(header: Text("Pricing & Measurement")) {
                    Picker("How is it sold? (Unit)", selection: $unitType) {
                        ForEach(UnitType.allCases) { unit in
                            Text(unit.displayName).tag(unit)
                        }
                    }

                    HStack {
                        Text("Price per \(unitType.shortLabel):")
                        Spacer()
                        TextField("0.00", value: $pricePerUnit, format: .number)
                            .frame(width: 120)
                            .multilineTextAlignment(.trailing)
                    }
                }

                Section(header: Text("Inventory & Notes")) {
                    Toggle("In Stock", isOn: $inStock)
                    TextField("Notes / Description (e.g. Fresh farm organic)", text: $notes)
                }
            }
            .formStyle(.grouped)
            .navigationTitle(existingItem == nil ? "Add Catalog Item" : "Edit Item")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveItem()
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || pricePerUnit <= 0)
                }
            }
            .frame(minWidth: 460, minHeight: 340)
            .onAppear {
                if let item = existingItem {
                    name = item.name
                    unitType = item.unitType
                    pricePerUnit = item.pricePerUnit
                    category = item.category
                    notes = item.notes
                    inStock = item.inStock
                }
            }
        }
    }

    private func saveItem() {
        let item = Item(
            id: existingItem?.id ?? UUID(),
            name: name.trimmingCharacters(in: .whitespaces),
            unitType: unitType,
            pricePerUnit: pricePerUnit,
            category: category,
            notes: notes.trimmingCharacters(in: .whitespaces),
            inStock: inStock
        )
        onSave(item)
    }
}
