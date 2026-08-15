import GameDomain

public enum WashBayRules {
    public static func currentDefinition(
        for state: GameState,
        catalog: ContentCatalog
    ) -> WashLevelDefinition? {
        catalog.washLevel(state.washLevel)
    }

    public static func nextDefinition(
        for state: GameState,
        catalog: ContentCatalog
    ) -> WashLevelDefinition? {
        catalog.washLevel(state.washLevel + 1)
    }

    public static func canUpgrade(
        state: GameState,
        definition: WashLevelDefinition
    ) -> Bool {
        state.shopLevel >= definition.requiredShopLevel && state.cash >= definition.upgradeCost
    }
}
