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

    public static func canHandle(
        _ job: RepairJob,
        apprentice: Apprentice,
        catalog: ContentCatalog
    ) -> Bool {
        if job.serviceKind == .periodicMaintenance {
            return job.maintenanceTasks.allSatisfy { canPerform($0, apprentice: apprentice) }
        }
        let possibleFaults = job.suspectedFaultIDs.compactMap(catalog.fault(id:))
        return !possibleFaults.isEmpty && possibleFaults.allSatisfy { canPerform($0, apprentice: apprentice) }
    }

    public static func workArea(for job: RepairJob, catalog: ContentCatalog) -> SkillArea? {
        if job.serviceKind == .periodicMaintenance {
            return job.maintenanceTasks.max { requiredLevel(for: $0) < requiredLevel(for: $1) }?.skillArea
        }
        return job.suspectedFaultIDs.compactMap(catalog.fault(id:))
            .max { $0.requiredSkill < $1.requiredSkill }?.area
    }

    public static func preparationDuration(
        for job: RepairJob,
        apprentice: Apprentice,
        catalog: ContentCatalog
    ) -> Int {
        let difficulty: Int
        if job.serviceKind == .periodicMaintenance {
            difficulty = job.maintenanceTasks.map(requiredLevel(for:)).max() ?? 1
        } else {
            difficulty = job.suspectedFaultIDs.compactMap(catalog.fault(id:)).map(\.requiredSkill).max() ?? 1
        }
        return adjustedDuration(baseMinutes: 35 + difficulty * 15, apprentice: apprentice)
    }

    public static func performance(
        apprentice: Apprentice,
        area: SkillArea,
        randomBonus: Int
    ) -> Int {
        let disciplineBonus = apprentice.traits.contains(.disciplined) ? 8 : 0
        let moodBonus = apprentice.happiness >= 75 ? 4 : (apprentice.happiness < 35 ? -8 : 0)
        return min(96, max(20, 46 + apprentice.skillLevel(for: area) * 9 + randomBonus + disciplineBonus + moodBonus))
    }

    public static func adjustedDuration(baseMinutes: Int, apprentice: Apprentice) -> Int {
        if apprentice.traits.contains(.hardworking) {
            return max(5, baseMinutes * 80 / 100)
        }
        if apprentice.traits.contains(.slowPaced) {
            return baseMinutes * 125 / 100
        }
        return baseMinutes
    }

    public static func departureRiskPercent(for apprentice: Apprentice, atMinute: Int) -> Int {
        guard apprentice.traits.contains(.entrepreneurial),
              apprentice.departureWarningMinute == nil,
              atMinute >= apprentice.retentionProtectedUntilMinute,
              atMinute - apprentice.hiredAtMinute >= 4 * 1_440,
              apprentice.jobsCompleted + apprentice.washesCompleted >= 7,
              apprentice.level >= 2 else { return 0 }
        let moodRisk = max(0, 65 - apprentice.happiness)
        return min(70, 8 + apprentice.level * 6 + moodRisk)
    }
}
