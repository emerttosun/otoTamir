import Foundation
import GameDomain

extension GameEngine {
    mutating func postApprenticeAd() throws -> [GameEvent] {
        guard let shop = catalog.shopLevel(state.shopLevel), shop.facilities.contains(.apprenticeStation) else {
            throw GameRuleError.invalidCommand("Çırak ilanı için çalışma tezgâhı olan daha büyük dükkân gerekli.")
        }
        guard state.apprentices.count < shop.maxApprentices else {
            throw GameRuleError.invalidCommand("Dükkândaki bütün çırak yerleri dolu.")
        }
        guard state.apprenticeRecruitment == nil else {
            throw GameRuleError.invalidCommand("Zaten yayında bir çırak ilanı veya bekleyen başvurular var.")
        }
        let cost = catalog.balance.apprenticeAdCost
        guard state.cash >= cost else { throw GameRuleError.notEnoughMoney }
        state.cash = state.cash - cost
        state.apprenticeRecruitment = ApprenticeRecruitment(
            postedAtMinute: state.totalMinutes,
            nextApplicationMinute: state.totalMinutes + 120
        )
        recordFinance(
            amount: Money(minorUnits: -cost.minorUnits),
            category: .recruitment,
            note: "Çırak ilanı"
        )
        return [.moneyChanged(Money(minorUnits: -cost.minorUnits), reason: "Çırak ilanı")]
    }

    mutating func acceptApprenticeApplication(_ applicationID: UUID) throws -> [GameEvent] {
        guard var recruitment = state.apprenticeRecruitment,
              let applicationIndex = recruitment.applications.firstIndex(where: { $0.id == applicationID }),
              let shop = catalog.shopLevel(state.shopLevel),
              state.apprentices.count < shop.maxApprentices else {
            throw GameRuleError.invalidCommand("Bu başvuru artık kabul edilemiyor veya boş çırak yeri yok.")
        }
        let application = recruitment.applications.remove(at: applicationIndex)
        let cost = catalog.balance.apprenticeHireCost
        guard state.cash >= cost else { throw GameRuleError.notEnoughMoney }
        var apprentice = Apprentice(
            id: application.id,
            name: application.name,
            background: application.background,
            traits: application.traits,
            revealedTraits: application.revealedTraits,
            hiredAtMinute: state.totalMinutes,
            lastRetentionCheckDay: state.day
        )
        if let startingArea = application.startingArea {
            apprentice.addExperience(area: startingArea, amount: application.startingExperience)
        } else {
            apprentice.addExperience(application.startingExperience)
        }
        state.cash = state.cash - cost
        state.apprentices.append(apprentice)
        recordFinance(
            amount: Money(minorUnits: -cost.minorUnits),
            category: .recruitment,
            note: "\(application.name) işe giriş ve ekipman"
        )
        if state.apprentices.count >= shop.maxApprentices {
            recruitment.isActive = false
        }
        state.apprenticeRecruitment = recruitment.isActive || !recruitment.applications.isEmpty ? recruitment : nil
        return [
            .moneyChanged(Money(minorUnits: -cost.minorUnits), reason: "Çırak işe alımı"),
            .apprenticeHired(apprentice)
        ]
    }

    mutating func rejectApprenticeApplication(_ applicationID: UUID) throws -> [GameEvent] {
        guard var recruitment = state.apprenticeRecruitment,
              let index = recruitment.applications.firstIndex(where: { $0.id == applicationID }) else {
            throw GameRuleError.invalidCommand("Bu çırak başvurusu artık bulunmuyor.")
        }
        let name = recruitment.applications.remove(at: index).name
        state.apprenticeRecruitment = recruitment.isActive || !recruitment.applications.isEmpty ? recruitment : nil
        return [.apprenticeApplicationRejected(name)]
    }

    mutating func giveApprenticeBonus(_ apprenticeID: UUID) throws -> [GameEvent] {
        guard let index = state.apprentices.firstIndex(where: { $0.id == apprenticeID }) else {
            throw GameRuleError.invalidCommand("Prim verilecek çırak bulunamadı.")
        }
        let cost = catalog.balance.apprenticeBonusCost
        guard state.cash >= cost else { throw GameRuleError.notEnoughMoney }
        state.cash = state.cash - cost
        state.apprentices[index].changeHappiness(by: 15)
        let apprentice = state.apprentices[index]
        recordFinance(
            amount: Money(minorUnits: -cost.minorUnits),
            category: .wages,
            note: "\(apprentice.name) performans primi"
        )
        return [
            .moneyChanged(Money(minorUnits: -cost.minorUnits), reason: "Çırak performans primi"),
            .apprenticeHappinessChanged(name: apprentice.name, happiness: apprentice.happiness)
        ]
    }

    mutating func processApprenticeRecruitment() -> [GameEvent] {
        guard var recruitment = state.apprenticeRecruitment, recruitment.isActive else { return [] }
        var random = SeededRandomSource(seed: state.randomSeed)
        var events: [GameEvent] = []
        while recruitment.nextApplicationMinute <= state.totalMinutes, recruitment.applications.count < 3 {
            if let application = makeApprenticeApplication(recruitment: recruitment, random: &random) {
                recruitment.applications.append(application)
                events.append(.apprenticeApplicationReceived(application))
            }
            recruitment.nextApplicationMinute += 240
        }
        if recruitment.applications.count >= 3 {
            recruitment.isActive = false
        }
        state.randomSeed = random.state
        state.apprenticeRecruitment = recruitment
        return events
    }

    mutating func processApprenticeRetention(newDay: Int) -> [GameEvent] {
        guard !state.apprentices.isEmpty else { return [] }
        var random = SeededRandomSource(seed: state.randomSeed)
        var events: [GameEvent] = []
        var departures: [Int] = []

        for index in state.apprentices.indices {
            guard state.apprentices[index].lastRetentionCheckDay < newDay else { continue }
            state.apprentices[index].lastRetentionCheckDay = newDay

            if state.apprentices[index].traits.contains(.loyal) {
                state.apprentices[index].changeHappiness(by: 1)
            }

            if let warningMinute = state.apprentices[index].departureWarningMinute {
                guard state.totalMinutes - warningMinute >= 2 * 1_440 else { continue }
                let name = state.apprentices[index].name
                if state.apprentices[index].happiness >= 80 {
                    state.apprentices[index].departureWarningMinute = nil
                    state.apprentices[index].retentionProtectedUntilMinute = state.totalMinutes + 10 * 1_440
                    events.append(.apprenticeStayed(name: name))
                    recordIncident(
                        kind: .apprentice,
                        message: "\(name), dükkândaki ortamdan memnun kalıp ayrılma düşüncesini şimdilik erteledi."
                    )
                } else {
                    departures.append(index)
                }
                continue
            }

            let risk = ApprenticeRules.departureRiskPercent(
                for: state.apprentices[index],
                atMinute: state.totalMinutes
            )
            guard risk > 0, random.next(upperBound: 100) < risk else { continue }
            let name = state.apprentices[index].name
            state.apprentices[index].departureWarningMinute = state.totalMinutes
            if !state.apprentices[index].revealedTraits.contains(.entrepreneurial) {
                state.apprentices[index].revealedTraits.append(.entrepreneurial)
                events.append(.apprenticeTraitRevealed(name: name, trait: .entrepreneurial))
            }
            events.append(.apprenticeDepartureWarning(name: name))
            recordIncident(
                kind: .apprentice,
                message: "\(name), kendi dükkânını açmayı düşündüğünü söyledi. İki gün içinde mutluluğu yükselmezse ayrılabilir."
            )
        }

        for index in departures.sorted(by: >) {
            let apprentice = state.apprentices[index]
            let shuffledFans = Array(apprentice.customerFans).sorted().shuffledDeterministically(using: &random)
            let takenCount = shuffledFans.isEmpty ? 0 : max(1, (shuffledFans.count + 1) / 2)
            state.lostCustomerIDs.formUnion(shuffledFans.prefix(takenCount))
            state.apprentices.remove(at: index)
            state.ratingTenths = max(10, state.ratingTenths - takenCount)
            events.append(.apprenticeLeft(name: apprentice.name, customersTaken: takenCount))
            recordIncident(
                kind: .apprentice,
                message: takenCount > 0
                    ? "\(apprentice.name) kendi yerini açıp ayrıldı; onu seven \(takenCount) müşteri de yeni dükkânına gitti."
                    : "\(apprentice.name) işi öğrenip kendi yerini açmak için dükkândan ayrıldı.",
                ratingImpact: -takenCount
            )
        }
        state.randomSeed = random.state
        return events
    }

    private func makeApprenticeApplication(
        recruitment: ApprenticeRecruitment,
        random: inout SeededRandomSource
    ) -> ApprenticeApplication? {
        let names = [
            "Mert", "Efe", "Can", "Burak", "Deniz", "Ayaz", "Emir", "Arda",
            "Kerem", "Oğuz", "Baran", "Umut", "Berk", "Yiğit", "Kaan", "Onur"
        ]
        let usedNames = Set(state.apprentices.map(\.name) + recruitment.applications.map(\.name))
        let availableNames = names.filter { !usedNames.contains($0) }
        guard !availableNames.isEmpty else { return nil }
        let name = availableNames[random.next(upperBound: availableNames.count)]
        let backgrounds = ApprenticeBackground.allCases
        let background = backgrounds[random.next(upperBound: backgrounds.count)]
        let experience: Int
        let startingArea: SkillArea?
        let introduction: String
        switch background {
        case .familyReferral:
            experience = random.next(upperBound: 21)
            startingArea = nil
            introduction = "Babasıyla geldi: ‘Okulla arası iyi gitmedi usta; eli işe yatkın, bir meslek öğrensin.’"
        case .vocationalHighSchool:
            experience = 55 + random.next(upperBound: 41)
            startingArea = SkillArea.allCases[random.next(upperBound: SkillArea.allCases.count)]
            introduction = "Motor bölümünden yeni mezun. Atölye stajı görmüş ama gerçek müşteri aracında tecrübesi az."
        case .vocationalTrainingCenter:
            experience = 35 + random.next(upperBound: 41)
            startingArea = SkillArea.allCases[random.next(upperBound: SkillArea.allCases.count)]
            introduction = "Mesleki eğitim merkezinde temel takım ve iş güvenliği eğitimi almış."
        case .selfApplication:
            experience = 10 + random.next(upperBound: 41)
            startingArea = nil
            introduction = "İlanı kendi görüp geldi: ‘Usta, işi yerinde öğrenmek istiyorum; süpürgeden kaçmam.’"
        }
        let traitPairs: [[ApprenticeTrait]] = [
            [.hardworking, .loyal], [.hardworking, .entrepreneurial],
            [.disciplined, .loyal], [.disciplined, .entrepreneurial],
            [.slowPaced, .loyal], [.slowPaced, .entrepreneurial],
            [.hardworking, .disciplined], [.slowPaced, .disciplined]
        ]
        let traits = traitPairs[random.next(upperBound: traitPairs.count)]
        let revealedTraits = random.next(upperBound: 100) < 35
            ? [traits[random.next(upperBound: traits.count)]]
            : []
        return ApprenticeApplication(
            id: random.nextUUID(),
            name: name,
            background: background,
            introduction: introduction,
            startingExperience: experience,
            startingArea: startingArea,
            traits: traits,
            revealedTraits: revealedTraits,
            appliedAtMinute: state.totalMinutes
        )
    }
}
