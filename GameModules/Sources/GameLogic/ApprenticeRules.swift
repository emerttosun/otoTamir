import GameDomain

public enum ApprenticeRules {
    public static func requiredLevel(for fault: FaultDefinition) -> Int {
        fault.requiredSkill
    }

    public static func requiredLevel(for task: MaintenanceTask) -> Int {
        switch task {
        case .oilAndFilter, .airFilter, .fluidCheck: 1
        case .batteryTest, .tireCheck: 2
        }
    }

    public static func canPerform(_ fault: FaultDefinition, apprentice: Apprentice) -> Bool {
        apprentice.skillLevel(for: fault.area) >= requiredLevel(for: fault)
    }

    public static func canPerform(_ task: MaintenanceTask, apprentice: Apprentice) -> Bool {
        apprentice.skillLevel(for: task.skillArea) >= requiredLevel(for: task)
    }

    public static func performance(
        apprentice: Apprentice,
        area: SkillArea,
        randomBonus: Int
    ) -> Int {
        min(92, 46 + apprentice.skillLevel(for: area) * 9 + randomBonus)
    }
}
