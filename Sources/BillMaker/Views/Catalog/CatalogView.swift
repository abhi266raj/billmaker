import SwiftUI

public struct CatalogView: View {
    @ObservedObject var appState: AppState
    @State private var searchText: String = ""
    @State private var selectedCategory: String = "All"
    @State private var editingItem: Item? = nil
    @State private var isAddingNewItem: Bool = false
    @State private var showResetAlert: Bool = false

    private var categories: [String] {
        let set = Set(appState.catalog.map { $0.category })
        var list = Array(set).sorted()
        list.insert("All", at: 0)
        return list
    }

    private var filteredItems: [Item] {
        appState.catalog.filter { item in
            let matchesCategory = (selectedCategory == "All") || (item.category == selectedCategory)
            if !matchesCategory { return false }

            let trimmed = searchText.lowercased().trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { return true }

            return item.name.lowercased().contains(trimmed) ||
                item.category.lowercased().contains(trimmed) ||
                item.unitType.rawValue.contains(trimmed)
        }
    }

    public init(appState: AppState) {
        self.appState = appState
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Header Bar
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        Text("Item Catalog & Context")
                            .font(.title2.bold())
                        Text("\(appState.catalog.count) items")
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.accentColor.opacity(0.15))
                            .foregroundColor(.accentColor)
                            .clipShape(Capsule())
                    }
                    Text("This catalog serves as the dynamic context given to the Apple Foundation Models AI Agent to bill items and prices.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button(action: { isAddingNewItem = true }) {
                    Label("Add Item", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)

                Menu {
                    Button("Reset to Default Items") {
                        showResetAlert = true
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .menuStyle(.borderlessButton)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            // Filters & Search
            HStack(spacing: 12) {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Search item name, category (e.g. Potato, Dairy)...", text: $searchText)
                        .textFieldStyle(.plain)
                    if !searchText.isEmpty {
                        Button(action: { searchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(7)
                .background(Color(NSColor.textBackgroundColor))
                .cornerRadius(8)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.2), lineWidth: 1))

                Picker("Category", selection: $selectedCategory) {
                    ForEach(categories, id: \.self) { cat in
                        Text(cat).tag(cat)
                    }
                }
                .frame(width: 180)
            }
            .padding(.horizontal)
            .padding(.vertical, 10)

            Divider()

            // Items Table
            if filteredItems.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "tray")
                        .font(.system(size: 44))
                        .foregroundColor(.secondary)
                    Text("No items found")
                        .font(.headline)
                    Text("Try adjusting your search query or add a new item.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Button("Add Item") {
                        isAddingNewItem = true
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Table(filteredItems) {
                    TableColumn("Item Name") { item in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.name)
                                .font(.body.weight(.medium))
                            if !item.notes.isEmpty {
                                Text(item.notes)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .width(min: 150, ideal: 200)

                    TableColumn("Category") { item in
                        Text(item.category)
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.secondary.opacity(0.12))
                            .cornerRadius(4)
                    }
                    .width(min: 100, ideal: 120)

                    TableColumn("Sold By") { item in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.unitType.displayName)
                                .font(.caption)
                            if item.sellingType == .packet {
                                Text(item.packetSize != nil ? "Packet (\(item.packetSize!))" : "Packet")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .width(min: 120, ideal: 150)

                    TableColumn("Price / Unit") { item in
                        Text("\(appState.settings.currencySymbol)\(String(format: "%.2f", item.pricePerUnit)) / \(item.unitType.shortLabel)")
                            .font(.body.weight(.semibold))
                            .foregroundColor(.accentColor)
                    }
                    .width(min: 100, ideal: 120)

                    TableColumn("Actions") { item in
                        HStack(spacing: 8) {
                            Button(action: { editingItem = item }) {
                                Image(systemName: "pencil")
                            }
                            .buttonStyle(.plain)
                            .help("Edit item")

                            Button(action: { appState.deleteItem(item) }) {
                                Image(systemName: "trash")
                                    .foregroundColor(.red)
                            }
                            .buttonStyle(.plain)
                            .help("Delete item")
                        }
                    }
                    .width(min: 60, ideal: 80)
                }
            }
        }
        .sheet(isPresented: $isAddingNewItem) {
            ItemEditorSheet { newItem in
                appState.addItem(newItem)
            }
        }
        .sheet(item: $editingItem) { item in
            ItemEditorSheet(existingItem: item) { updated in
                appState.updateItem(updated)
            }
        }
        .alert("Reset Catalog to Defaults?", isPresented: $showResetAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Reset", role: .destructive) {
                appState.resetCatalogToDefaults()
            }
        } message: {
            Text("This will replace all current items with the default grocery and vegetable catalog.")
        }
    }
}
