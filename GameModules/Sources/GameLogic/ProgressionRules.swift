import GameDomain

public enum ProgressionRules {
    public static func availableFaults(in catalog: ContentCatalog, state: GameState) -> [FaultDefinition] {
        let unlocked = catalog.faults.filter { fault in
            state.expertise[fault.area, default: SkillProgress()].level >= fault.requiredSkill
        }
        if !unlocked.isEmpty { return unlocked }
        guard let minimum = catalog.faults.map(\.requiredSkill).min() else { return [] }
        return catalog.faults.filter { $0.requiredSkill == minimum }
    }

    public static func availableCustomers(in catalog: ContentCatalog, state: GameState) -> [CustomerDefinition] {
        let mastery = highestExpertise(in: state)
        let unlocked = catalog.customers.filter { $0.minimumExpertise <= mastery }
        return unlocked.isEmpty ? Array(catalog.customers.prefix(1)) : unlocked
    }

    public static func unlockedVehicleCount(in catalog: ContentCatalog, state: GameState) -> Int {
        let averageMastery = max(
            1,
            SkillArea.allCases.map { state.expertise[$0, default: SkillProgress()].level }.reduce(0, +)
                / SkillArea.allCases.count
        )
        return min(catalog.vehicles.count, 3 + max(0, state.shopLevel - 1) + max(0, averageMastery - 1))
    }

    public static func nextFault(
        for area: SkillArea,
        in catalog: ContentCatalog,
        state: GameState
    ) -> FaultDefinition? {
        let level = state.expertise[area, default: SkillProgress()].level
        return catalog.faults
            .filter { $0.area == area && $0.requiredSkill > level }
            .sorted { lhs, rhs in
                lhs.requiredSkill == rhs.requiredSkill ? lhs.name < rhs.name : lhs.requiredSkill < rhs.requiredSkill
            }
            .first
    }

    public static func highestExpertise(in state: GameState) -> Int {
        SkillArea.allCases.map { state.expertise[$0, default: SkillProgress()].level }.max() ?? 1
    }
}
