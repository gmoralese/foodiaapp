import SwiftUI

struct RootView: View {
    @AppStorage("hasOnboarded") private var hasOnboarded = false
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @State private var tab: AppTab = .today
    @State private var showCamera = false
    @State private var toastMessage: String?

    init() {
        #if DEBUG
        // Para screenshots/desarrollo: -initialTab history|goals|settings
        let arguments = ProcessInfo.processInfo.arguments
        if let index = arguments.firstIndex(of: "-initialTab"), arguments.indices.contains(index + 1) {
            switch arguments[index + 1] {
            case "history": _tab = State(initialValue: .history)
            case "goals": _tab = State(initialValue: .goals)
            case "settings": _tab = State(initialValue: .settings)
            default: break
            }
        }
        #endif
    }

    var body: some View {
        Group {
            if hasOnboarded && AuthService.shared.isAuthenticated {
                mainApp
            } else {
                FirstRunFlow()
            }
        }
        .task {
            SyncService.shared.configure(container: modelContext.container)
            GoalsStore.shared.didChange = { SyncService.shared.pushProfileSnapshot() }
            await AuthService.shared.start()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { SyncService.shared.syncNow() }
        }
    }

    private var mainApp: some View {
        Group {
            switch tab {
            case .today:
                TodayView(
                    onCapture: { showCamera = true },
                    onSeeAll: { tab = .history }
                )
            case .history:
                HistoryView(onCapture: { showCamera = true })
            case .goals:
                GoalsView()
            case .settings:
                SettingsView()
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            FoodiaTabBar(selection: $tab) {
                showCamera = true
            }
        }
        .fullScreenCover(isPresented: $showCamera) {
            CaptureFlowView { savedMessage in
                toastMessage = savedMessage
                tab = .today
            }
        }
        .toast(message: $toastMessage)
    }
}
