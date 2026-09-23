import AppKit
import CodexBarCore
import Testing
@testable import CodexBar

/// MiMo reports a monetary balance where quota-based providers report a percentage, so stored menu bar
/// layouts have to render that balance in both the `Balance` token and the automatic percentage lane,
/// while token-plan accounts keep their percentage.
///
/// Kept in its own suite: `StatusItemBalanceDisplayTests` is already at the file and type body limits.
@Suite(.serialized)
@MainActor
struct MiMoMenuBarBalanceLayoutTests {
    @Test
    func `stored balance token layout shows the mimo balance in status item and preview`() {
        let layout = MenuBarLayout(lines: [[.icon, .balance]])
        let settings = self.makeSettings(layout: layout)
        let (store, controller) = self.makeStoreAndController(settings: settings)
        defer { controller.releaseStatusItemsForTesting() }
        let snapshot = Self.balanceOnlySnapshot()

        store._setSnapshotForTesting(snapshot, provider: .mimo)
        store._setErrorForTesting(nil, provider: .mimo)

        for data in self.renderData(
            layout: layout,
            settings: settings,
            store: store,
            controller: controller,
            snapshot: snapshot)
        {
            #expect(data.balance == "CN¥4.84")
            #expect(Self.render(layout: layout, data: data).attributedTitle.string.hasSuffix("CN¥4.84"))
        }
    }

    @Test
    func `stored automatic layout shows the mimo balance in status item and preview`() {
        let layout = MenuBarLayout(lines: [[.icon, .percent(window: .automatic)]])
        let settings = self.makeSettings(layout: layout)
        let (store, controller) = self.makeStoreAndController(settings: settings)
        defer { controller.releaseStatusItemsForTesting() }
        let snapshot = Self.balanceOnlySnapshot()

        store._setSnapshotForTesting(snapshot, provider: .mimo)
        store._setErrorForTesting(nil, provider: .mimo)

        for data in self.renderData(
            layout: layout,
            settings: settings,
            store: store,
            controller: controller,
            snapshot: snapshot)
        {
            // A balance-only account has no quota window, so the automatic lane falls back to the balance.
            #expect(data.automatic == nil)
            #expect(data.automaticText == "CN¥4.84")
            #expect(Self.render(layout: layout, data: data).attributedTitle.string.hasSuffix("CN¥4.84"))
        }
    }

    @Test
    func `stored automatic layout keeps the percent for a mimo token plan`() {
        let layout = MenuBarLayout(lines: [[.icon, .percent(window: .automatic)]])
        let settings = self.makeSettings(layout: layout)
        let (store, controller) = self.makeStoreAndController(settings: settings)
        defer { controller.releaseStatusItemsForTesting() }
        let snapshot = MiMoUsageSnapshot(
            balance: 25.51,
            currency: "USD",
            planCode: "standard",
            tokenUsed: 25,
            tokenLimit: 100,
            tokenPercent: 0.25,
            updatedAt: Date())
            .toUsageSnapshot()

        store._setSnapshotForTesting(snapshot, provider: .mimo)
        store._setErrorForTesting(nil, provider: .mimo)

        let data = controller.menuBarLayoutRenderData(
            provider: .mimo,
            snapshot: snapshot,
            warningFlash: false)

        #expect(data.automatic != nil)
        #expect(data.automaticText == nil)
        #expect(Self.render(layout: layout, data: data).attributedTitle.string.hasSuffix("25%"))
    }

    private static func balanceOnlySnapshot() -> UsageSnapshot {
        MiMoUsageSnapshot(
            balance: 4.84,
            currency: "CNY",
            cashBalance: 4.84,
            giftBalance: 0,
            updatedAt: Date())
            .toUsageSnapshot()
    }

    /// Both surfaces resolve the stored layout independently, so every token assertion covers the status
    /// item data builder and the editor preview builder.
    private func renderData(
        layout: MenuBarLayout,
        settings: SettingsStore,
        store: UsageStore,
        controller: StatusItemController,
        snapshot: UsageSnapshot)
        -> [MenuBarLayoutRenderData]
    {
        [
            controller.menuBarLayoutRenderData(
                provider: .mimo,
                snapshot: snapshot,
                warningFlash: false),
            MenuBarLayoutPreview(layout: layout, provider: .mimo, settings: settings, store: store)
                .liveData(provider: .mimo, snapshot: snapshot),
        ]
    }

    private static func render(layout: MenuBarLayout, data: MenuBarLayoutRenderData) -> MenuBarLayoutRenderedTitle {
        MenuBarLayoutRenderer().render(
            layout: layout,
            data: data,
            icon: NSImage(size: NSSize(width: 16, height: 16)),
            options: MenuBarLayoutRenderOptions(
                size: .regular,
                highContrast: false,
                showUsed: true,
                conditionals: [],
                appearanceName: "aqua",
                isDebugApp: false,
                now: Date()))
    }

    private func makeSettings(layout: MenuBarLayout) -> SettingsStore {
        let settings = testSettingsStore(
            suiteName: "MiMoMenuBarBalanceLayoutTests",
            userDefaults: InMemoryUserDefaults())
        settings.statusChecksEnabled = false
        settings.refreshFrequency = .manual
        settings.mergeIcons = true
        settings.selectedMenuProvider = UsageProvider.mimo.instanceID
        settings.menuBarDisplayMode = .both
        settings.usageBarsShowUsed = true
        settings.setMenuBarLayout(layout, for: nil)

        let registry = ProviderRegistry.shared
        if let metadata = registry.metadata[.mimo] {
            settings.setProviderEnabled(provider: .mimo, metadata: metadata, enabled: true)
        }
        return settings
    }

    private func makeStoreAndController(settings: SettingsStore) -> (UsageStore, StatusItemController) {
        let fetcher = UsageFetcher()
        let store = UsageStore(fetcher: fetcher, browserDetection: BrowserDetection(cacheTTL: 0), settings: settings)
        let controller = StatusItemController(
            store: store,
            settings: settings,
            account: fetcher.loadAccountInfo(),
            updater: DisabledUpdaterController(),
            preferencesSelection: PreferencesSelection(),
            statusBar: testStatusBar())
        return (store, controller)
    }
}
