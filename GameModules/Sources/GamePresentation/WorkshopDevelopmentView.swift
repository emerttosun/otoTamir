import GameDomain
import GameLogic
import SwiftUI

struct WorkshopDevelopmentView: View {
    @ObservedObject var store: GameStore

    var body: some View {
        VStack(spacing: 12) {
            shopCard
            washCard
            masteryCard
        }
        .padding(.horizontal, 12)
    }

    private var washCard: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack {
                Label("Yıkama Bölümü", systemImage: "drop.fill").font(.headline)
                Spacer()
                Text(store.state.washLevel == 0 ? "KAPALI" : "SEVİYE \(store.state.washLevel)")
                    .font(.caption2.bold())
                    .foregroundStyle(store.state.washLevel == 0 ? Color.secondary : Color.blue)
            }

            HStack(spacing: 8) {
                ForEach(store.catalog.washLevels) { level in
                    VStack(spacing: 4) {
                        Image(systemName: level.id <= store.state.washLevel ? "drop.circle.fill" : "drop.circle")
                            .font(.title3)
                        Text("Sv. \(level.id)").font(.caption2.bold())
                    }
                    .foregroundStyle(level.id <= store.state.washLevel ? Color.blue : Color.secondary)
                    .frame(maxWidth: .infinity)
                }
            }

            if let current = WashBayRules.currentDefinition(for: store.state, catalog: store.catalog) {
                Text(current.name).font(.subheadline.bold())
                Text("\(current.detail) • \(current.durationMinutes) dk • kullanım \(current.washCost.liraText)")
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                Text("Teslimden önce araç yıkama henüz açık değil.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            if let next = WashBayRules.nextDefinition(for: store.state, catalog: store.catalog) {
                Divider().overlay(.white.opacity(0.12))
                Text("SIRADAKİ: \(next.name.uppercased())")
                    .font(.caption2.bold()).foregroundStyle(GarageStyle.orange)
                Text(next.detail).font(.caption)
                if store.state.shopLevel < next.requiredShopLevel {
                    Label("Dükkân Seviye \(next.requiredShopLevel) gerekli", systemImage: "lock.fill")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Button("Yıkamayı Geliştir • \(next.upgradeCost.liraText)") {
                    store.send(.upgradeWashBay)
                }
                .buttonStyle(ActionButtonStyle(tint: .blue))
                .disabled(store.state.shopLevel < next.requiredShopLevel)
            } else {
                Label("Yıkama bölümü en yüksek seviyede", systemImage: "checkmark.seal.fill")
                    .font(.subheadline).foregroundStyle(GarageStyle.mint)
            }
        }
        .garageCard()
    }

    private var shopCard: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack {
                Label("Dükkân Gelişimi", systemImage: "building.2.fill").font(.headline)
                Spacer()
                Text("SEVİYE \(store.state.shopLevel)")
                    .font(.caption2.bold())
                    .foregroundStyle(GarageStyle.orange)
            }

            if let current = store.catalog.shopLevel(store.state.shopLevel) {
                Text(current.name).font(.title3.bold())
                HStack(spacing: 8) {
                    metricPill("\(current.capacity) araç", icon: "car.2.fill")
                    metricPill("+\(current.equipmentBonus) ekipman", icon: "wrench.and.screwdriver.fill")
                    metricPill("\(current.maxApprentices) çırak", icon: "person.2.fill")
                }

                LazyVGrid(columns: [.init(.flexible()), .init(.flexible())], alignment: .leading, spacing: 7) {
                    ForEach(current.facilities, id: \.self) { facility in
                        Label(facility.title, systemImage: "checkmark.circle.fill")
                            .font(.caption2).foregroundStyle(GarageStyle.mint)
                    }
                }
            }

            if let next = store.catalog.shopLevel(store.state.shopLevel + 1) {
                Divider().overlay(.white.opacity(0.12))
                Text("SONRAKİ GELİŞTİRME")
                    .font(.caption2.bold()).foregroundStyle(.secondary)
                Text(next.name).font(.subheadline.bold())
                ForEach(newFacilities(in: next), id: \.self) { facility in
                    Label(facility.title, systemImage: "lock.open.fill")
                        .font(.caption).foregroundStyle(GarageStyle.orange)
                }
                Button("Dükkânı Geliştir • \(next.upgradeCost.liraText)") {
                    store.send(.upgradeShop)
                }
                .buttonStyle(ActionButtonStyle())
            } else {
                Label("Dükkân en yüksek seviyede", systemImage: "checkmark.seal.fill")
                    .font(.subheadline).foregroundStyle(GarageStyle.mint)
            }
        }
        .garageCard()
    }

    private var masteryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Ustalık ve İtibar", systemImage: "star.bubble.fill").font(.headline)
                Spacer()
                Text("★ \(store.state.shopRatingText)")
                    .font(.headline.monospacedDigit()).foregroundStyle(GarageStyle.orange)
            }

            reputationMetric("İşçilik", value: store.state.reputation.craftsmanship, tint: GarageStyle.mint)
            reputationMetric("Güven", value: store.state.reputation.trust, tint: .blue)
            reputationMetric("Şaibe", value: store.state.reputation.suspicion, tint: GarageStyle.danger)

            Divider().overlay(.white.opacity(0.12))
            ForEach(SkillArea.allCases, id: \.self) { skill in
                let progress = store.state.expertise[skill, default: SkillProgress()]
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(skill.title).font(.caption)
                        Spacer()
                        Text("Sv. \(progress.level) • \(progress.experience)/\(progress.experienceForNextLevel) XP")
                            .font(.caption2.bold().monospacedDigit())
                    }
                    SwiftUI.ProgressView(value: Double(progress.experience), total: Double(progress.experienceForNextLevel))
                        .tint(GarageStyle.orange)
                    if let next = ProgressionRules.nextFault(for: skill, in: store.catalog, state: store.state) {
                        Label("Sv. \(next.requiredSkill): \(next.name) açılır", systemImage: "lock.open.fill")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    } else {
                        Label("Bu alandaki mevcut işlerin tamamı açık", systemImage: "checkmark.seal.fill")
                            .font(.caption2)
                            .foregroundStyle(GarageStyle.mint)
                    }
                }
            }
        }
        .garageCard()
    }

    private func metricPill(_ text: String, icon: String) -> some View {
        Label(text, systemImage: icon)
            .font(.system(size: 9, weight: .bold))
            .lineLimit(1)
            .padding(.horizontal, 7)
            .padding(.vertical, 6)
            .background(GarageStyle.raised, in: Capsule())
    }

    private func reputationMetric(_ title: String, value: Int, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title).font(.caption)
                Spacer()
                Text("%\(value)").font(.caption.bold().monospacedDigit())
            }
            SwiftUI.ProgressView(value: Double(value), total: 100).tint(tint)
        }
    }

    private func newFacilities(in next: ShopLevelDefinition) -> [ShopFacility] {
        let current = store.catalog.shopLevel(store.state.shopLevel)?.facilities ?? []
        return next.facilities.filter { !current.contains($0) }
    }
}
