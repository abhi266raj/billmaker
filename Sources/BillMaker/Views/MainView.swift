import SwiftUI

public enum NavigationSection: String, CaseIterable, Identifiable {
    case catalog = "catalog"
    case harness = "harness"
    case settings = "settings"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .catalog: return "Item Catalog"
        case .harness: return "Agent Harness"
        case .settings: return "Settings"
        }
    }

    public var icon: String {
        switch self {
        case .catalog: return "list.bullet.rectangle.portrait"
        case .harness: return "sparkles.rectangle.stack"
        case .settings: return "gearshape"
        }
    }
}

public struct MainView: View {
    @StateObject private var appState = AppState()
    @State private var selectedSection: NavigationSection? = .catalog

    public init() {}

    public var body: some View {
        NavigationSplitView {
            List(selection: $selectedSection) {
                Section(header: Text("WORKSPACE")) {
                    NavigationLink(value: NavigationSection.catalog) {
                        Label(NavigationSection.catalog.title, systemImage: NavigationSection.catalog.icon)
                            .badge(appState.catalog.count)
                    }

                    NavigationLink(value: NavigationSection.harness) {
                        Label(NavigationSection.harness.title, systemImage: NavigationSection.harness.icon)
                    }
                }

                Section(header: Text("CONFIGURATION")) {
                    NavigationLink(value: NavigationSection.settings) {
                        Label(NavigationSection.settings.title, systemImage: NavigationSection.settings.icon)
                    }
                }
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 280)
        } detail: {
            switch selectedSection {
            case .catalog:
                CatalogView(appState: appState)
            case .harness:
                AgentHarnessView(appState: appState)
            case .settings:
                SettingsView(appState: appState)
            case .none:
                Text("Select an option from the sidebar")
                    .foregroundColor(.secondary)
            }
        }
        .frame(minWidth: 960, minHeight: 640)
    }
}
