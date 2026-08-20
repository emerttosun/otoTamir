import Foundation
import GameDomain

extension GameEngine {
    mutating func grantPurchase(transactionID: String, cash: Money?, themeID: String?) -> [GameEvent] {
        guard !state.processedTransactionIDs.contains(transactionID) else { return [] }
        state.processedTransactionIDs.insert(transactionID)
        if let cash { state.cash = state.cash + cash }
        if let themeID { state.selectedThemeID = themeID }
        var events: [GameEvent] = [.purchaseGranted(transactionID)]
        if let cash { events.append(.moneyChanged(cash, reason: "Mağaza paketi")) }
        return events
    }

    mutating func makeCustomerOffer() -> CustomerOffer? {
        let unlockedVehicleCount = ProgressionRules.unlockedVehicleCount(in: catalog, state: state)
        let vehicles = Array(catalog.vehicles.prefix(unlockedVehicleCount))
        let unlockedCustomers = ProgressionRules.availableCustomers(in: catalog, state: state)
        let retainedCustomers = unlockedCustomers.filter { !state.lostCustomerIDs.contains($0.id) }
        let customers = retainedCustomers.isEmpty ? unlockedCustomers : retainedCustomers
        let faults = ProgressionRules.availableFaults(in: catalog, state: state)
        guard !customers.isEmpty, !vehicles.isEmpty, !faults.isEmpty else { return nil }

        var random = SeededRandomSource(seed: state.randomSeed)
        let customer = customers[random.next(upperBound: customers.count)]
        let vehicle = vehicles[random.next(upperBound: vehicles.count)]
        let isMaintenance = supports(.periodicMaintenance) && random.next(upperBound: 100) < 24
        let waitingAreaBonus = supports(.waitingArea) ? 60 : 0
        let requestedApprentice = state.apprentices.first { $0.customerFans.contains(customer.id) }
        let requestPrefix = requestedApprentice.map {
            "‘\($0.name) burada mı usta? Geçen işi o toplamıştı.’ "
        } ?? ""
        let offer: CustomerOffer
        if isMaintenance {
            let count = 3 + random.next(upperBound: 3)
            let tasks = Array(MaintenanceTask.allCases.shuffledDeterministically(using: &random).prefix(count))
            offer = CustomerOffer(
                id: random.nextUUID(),
                customerID: customer.id,
                vehicleID: vehicle.id,
                serviceKind: .periodicMaintenance,
                actualFaultID: nil,
                suspectedFaultIDs: [],
                maintenanceTasks: tasks,
                complaint: requestPrefix + "Yıllık bakım zamanı geldi. Yağına suyuna bakıp içimizi rahatlat usta.",
                arrivedAtMinute: state.totalMinutes,
                expiresAtMinute: state.totalMinutes + 180 + waitingAreaBonus
            )
        } else {
            let actual = faults[random.next(upperBound: faults.count)]
            let alternatives = faults
                .filter { $0.id != actual.id && ($0.area == actual.area || sharesInspection($0, actual)) }
                .shuffledDeterministically(using: &random)
            let candidateIDs = ([actual.id] + alternatives.prefix(3).map(\.id)).shuffledDeterministically(using: &random)
            offer = CustomerOffer(
                id: random.nextUUID(),
                customerID: customer.id,
                vehicleID: vehicle.id,
                actualFaultID: actual.id,
                suspectedFaultIDs: candidateIDs,
                complaint: requestPrefix + ([actual.complaint] + actual.complaintVariants)[
                    random.next(upperBound: max(1, actual.complaintVariants.count + 1))
                ],
                arrivedAtMinute: state.totalMinutes,
                expiresAtMinute: state.totalMinutes + 180 + waitingAreaBonus
            )
        }
        state.randomSeed = random.state
        return offer
    }

    mutating func scheduleNextCustomer() {
        var random = SeededRandomSource(seed: state.randomSeed)
        let ratingAdvantage = max(0, state.ratingTenths - 30) * 2
        let base = max(35, 105 - ratingAdvantage)
        state.nextCustomerArrivalMinute = max(state.totalMinutes + 5, state.nextCustomerArrivalMinute) + base + random.next(upperBound: 61)
        state.randomSeed = random.state
    }

    var isBusinessHour: Bool {
        let minute = state.minuteOfDay
        return minute >= 8 * 60 && minute < 20 * 60
    }

    func nextOpeningMinute(after minute: Int) -> Int {
        let dayStart = minute - minute % 1_440
        if minute % 1_440 < 8 * 60 { return dayStart + 8 * 60 }
        return dayStart + 1_440 + 8 * 60
    }

    func inferredInspections(for area: SkillArea) -> Set<InspectionKind> {
        switch area {
        case .engine: [.visual, .startEngine, .listen, .fluids, .diagnosticScanner]
        case .electrical: [.startEngine, .diagnosticScanner, .visual]
        case .chassis: [.lift, .wheelPlay, .testDrive, .listen]
        case .body: [.visual, .lift]
        }
    }

    func fallbackFinding(for fault: FaultDefinition, inspection: InspectionKind) -> String {
        let relevant = inferredInspections(for: fault.area).contains(inspection)
        if relevant, let clue = fault.clues.first { return clue }
        return "Bu kontrolde belirgin bir sorun görülmedi."
    }

    func sharesInspection(_ lhs: FaultDefinition, _ rhs: FaultDefinition) -> Bool {
        let left = Set(lhs.inspectionFindings.keys).union(inferredInspections(for: lhs.area))
        let right = Set(rhs.inspectionFindings.keys).union(inferredInspections(for: rhs.area))
        return !left.isDisjoint(with: right)
    }

    mutating func grantExperience(area: SkillArea, amount: Int) -> GameEvent {
        var progress = state.expertise[area, default: SkillProgress()]
        progress.addExperience(amount)
        state.expertise[area] = progress
        state.skills[area] = progress.level
        return .experienceGained(area: area, amount: amount, level: progress.level)
    }

    func workmanship(for score: Int) -> WorkmanshipQuality {
        score >= 82 ? .good : (score >= 55 ? .acceptable : .poor)
    }

    mutating func applyReputation(
        for quality: WorkmanshipQuality,
        strategy: PriceStrategy,
        concealed: Bool,
        noticed: Bool
    ) {
        switch quality {
        case .good:
            state.reputation.craftsmanship += 4
            state.reputation.trust += strategy == .affordable || strategy == .fair ? 3 : 1
        case .acceptable:
            state.reputation.craftsmanship += 1
        case .poor:
            state.reputation.craftsmanship -= 5
            state.reputation.trust -= 3
        }
        if concealed { state.reputation.suspicion += 6 }
        if noticed { state.reputation.trust -= 2 }
        state.reputation.clamp()
    }

    mutating func makeReview(
        for job: RepairJob,
        workmanship: WorkmanshipQuality,
        strategy: PriceStrategy,
        noticed: Bool,
        random: inout SeededRandomSource
    ) -> ShopReview? {
        let tone: ReviewTone
        var stars: Int
        if noticed || workmanship == .poor {
            tone = .negative
            stars = noticed && workmanship == .poor ? 1 : 2
        } else if workmanship == .good && (strategy == .affordable || strategy == .fair) {
            tone = .positive
            stars = 5
        } else {
            tone = .neutral
            stars = strategy == .excessive ? 3 : 4
        }
        if job.isWashed, !noticed, workmanship != .poor {
            stars = min(5, stars + 1)
        }
        let chance = tone == .neutral ? 45 : 78
        guard random.next(upperBound: 100) < chance else { return nil }
        let templates = catalog.reviews.filter { $0.tone == tone }
        let fallback: String
        switch tone {
        case .positive: fallback = "İşi temiz yaptı, fiyatı da baştan düşündüğüm gibiydi."
        case .neutral: fallback = "İş görüldü, biraz bekledim ama araç düzeldi."
        case .negative: fallback = "Fiyat sonradan değişti; bir daha gelmeden önce iki kere düşünürüm."
        }
        let text = templates.isEmpty ? fallback : templates[random.next(upperBound: templates.count)].text
        return ShopReview(id: random.nextUUID(), customerID: job.customerID, stars: stars, text: text, day: state.day)
    }

    mutating func addReview(_ review: ShopReview) {
        let weight = min(20, 5 + state.reviews.count)
        state.ratingTenths = min(50, max(10, (state.ratingTenths * weight + review.stars * 10) / (weight + 1)))
        state.reviews.append(review)
        if state.reviews.count > 30 { state.reviews.removeFirst(state.reviews.count - 30) }
    }

    mutating func scheduleConsequences(
        for job: RepairJob,
        paid: Money,
        quality: WorkmanshipQuality,
        partQuality: PartQuality,
        strategy: PriceStrategy,
        concealed: Bool,
        noticed: Bool,
        random: inout SeededRandomSource
    ) {
        let risky = quality == .poor || partQuality == .used || concealed
        if risky && random.next(upperBound: 100) < 62 {
            let isInspection = state.reputation.suspicion > 35
            let inspectionMessages = [
                "Esnaf denetimi geldi. Parça alış kaydıyla müşteriye anlatılan kalite uyuşmayınca tutanak ve ceza çıktı.",
                "Denetçi rafı, fişi ve sökülen parçayı yan yana koydu: ‘Usta, bu hesap lifte sığmıyor.’ Ceza kesildi.",
                "Şikâyet üzerine dükkân kayıtları incelendi. Belgesiz işlem ve fiyat farkı için idari ceza uygulandı.",
                "Denetim ekibi ‘yan sanayi’ kutusunu açıp faturadaki ‘orijinal’ satırını gördü. Açıklama yetmedi, ceza çıktı.",
                "Sanayi odasından kontrol geldi. Garanti ve parça bilgisi eksik olduğu için tutanak tutuldu.",
                "Denetçi tezgâhtaki kutuyla stok kaydını eşleştiremedi. ‘Bu parça nereden geldi?’ sorusu cezayla kapandı.",
                "Müşteri beyanıyla iş emri karşılaştırıldı. Onay alınmadan eklenen işlem için para cezası uygulandı.",
                "Kontrolde eski parçanın müşteriye gösterilmediği ve kalite bilgisinin saklandığı belirlendi. Tutanak tutuldu.",
                "Garanti sözü kayıtlarda bulunamayınca denetçi kalemi bırakmadı. Dükkâna ceza ve uyarı yazıldı.",
                "Fiyat listesiyle kasadaki tahsilat birbirini tutmadı. Denetim, aradaki farkı ustaya masraf olarak geri yazdı."
            ]
            let complaintMessages = [
                "Müşteri aynı sesle geri geldi: ‘Usta radyoyu açınca geçiyor demiştin, radyo da bozuldu.’ Telafi masrafı çıktı.",
                "Takılan parça iki gün sonra sorun çıkardı; müşteri çayı bu kez şekersiz içti. Ücretsiz düzeltme yapıldı.",
                "Müşteri başka dükkândan aldığı fiyatı gösterdi. Fazla alınan kısmın bir bölümü iade edildi.",
                "Araç yolda tekrar arıza verince çekiciyle kapıya geldi. Çekici ve telafi bedeli dükkâna yazıldı.",
                "Gizlenen çıkma parça başka ustanın kontrolünde ortaya çıktı. Müşteri iade ve yeniden onarım istedi.",
                "Telefon sabah erkenden çaldı: ‘Usta ses gitti ama lambalar kurul yaptı.’ Araç yeniden işleme alındı.",
                "Müşteri sökülen parçanın fotoğrafını istedi; anlatılanla takılan uyuşmayınca ücret iadesi yapıldı.",
                "Araç ilk rampada yine bağırmaya başladı. Müşteri ‘Ben motor sesi değil yol almak istemiştim’ diyerek geri döndü.",
                "Tamponun köşesi ilk kasiste yeniden ayrıldı. Bant değil işçilik isteyen müşteriye ücretsiz düzeltme yapıldı.",
                "Kapı bu kez kapandı ama cam sürtme sesi yaptı. Eksik ayar için araç yeniden lifte alındı."
            ]
            state.consequences.append(ScheduledConsequence(
                id: random.nextUUID(),
                dueDay: state.day + 1 + random.next(upperBound: 3),
                kind: isInspection ? .inspection : .complaint,
                amount: percent(paid, isInspection ? 45 : 20),
                message: isInspection
                    ? inspectionMessages[random.next(upperBound: inspectionMessages.count)]
                    : complaintMessages[random.next(upperBound: complaintMessages.count)]
            ))
        }
    }

}
