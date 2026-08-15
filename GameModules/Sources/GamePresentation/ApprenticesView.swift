import GameDomain
import SwiftUI

struct ApprenticesView: View {
    @ObservedObject var store: GameStore

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                header
                roster
                recruitmentCard
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("USTA–ÇIRAK TEZGÂHI")
                .font(.caption.weight(.black)).foregroundStyle(GarageStyle.orange)
            Text("Çırakların").font(.title3.bold())
            Text("Sanayiye çırak ilanı as, başvuranları tanı, kadroya al ve işi yanında öğrenmelerini sağla.")
                .font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .garageCard()
    }

    private var roster: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Kadro", systemImage: "person.2.fill").font(.headline)
            if store.state.apprentices.isEmpty {
                Text("Henüz yanında çalışan çırak yok.")
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                ForEach(store.state.apprentices) { apprentice in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            ZStack {
                                Circle().fill(GarageStyle.orange.opacity(0.18)).frame(width: 42, height: 42)
                                Image(systemName: "person.fill").foregroundStyle(GarageStyle.orange)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(apprentice.name).font(.subheadline.bold())
                                Text("\(apprentice.background.title) • Seviye \(apprentice.level)")
                                    .font(.caption2).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text("\(apprentice.experience)/\(apprentice.level * 100) XP")
                                .font(.caption2.bold().monospacedDigit())
                        }
                        SwiftUI.ProgressView(
                            value: Double(apprentice.experience),
                            total: Double(apprentice.level * 100)
                        )
                        .tint(GarageStyle.orange)
                    }
                    .padding(10)
                    .background(GarageStyle.raised.opacity(0.7), in: RoundedRectangle(cornerRadius: 12))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .garageCard()
    }

    private var recruitmentCard: some View {
        VStack(alignment: .leading, spacing: 9) {
            Label("Çırak İlanı ve Başvurular", systemImage: "person.crop.rectangle.stack.fill").font(.headline)
            if currentShop?.facilities.contains(.apprenticeStation) != true {
                Label("Çırak tezgâhı Dükkân Gelişimi ile açılır", systemImage: "lock.fill")
                    .font(.caption).foregroundStyle(.secondary)
            } else if availableSlots == 0 {
                Label("Bütün çırak yerleri dolu", systemImage: "checkmark.circle.fill")
                    .font(.caption).foregroundStyle(GarageStyle.mint)
            } else {
                HStack {
                    Text("Boş çırak yeri: \(availableSlots)")
                    Spacer()
                    Text("İşe giriş: \(store.catalog.balance.apprenticeHireCost.liraText)")
                }
                .font(.caption).foregroundStyle(.secondary)

                if let recruitment = store.state.apprenticeRecruitment {
                    if recruitment.applications.isEmpty {
                        Text("İlan yayında. Henüz başvuru yok.")
                            .font(.caption).foregroundStyle(.secondary)
                    } else {
                        ForEach(recruitment.applications) { application in
                            applicationCard(application)
                        }
                    }
                    if recruitment.isActive {
                        Button("Yeni Başvuruları Kontrol Et") {
                            store.send(.checkApprenticeApplications)
                        }
                        .buttonStyle(ActionButtonStyle(tint: GarageStyle.orange))
                    } else {
                        Text("İlan başvuru sınırına ulaştı. Adayları değerlendirince yeniden ilan açabilirsin.")
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                } else {
                    Text("İlan; kendi gelen, ailesi tarafından getirilen veya meslek eğitimi görmüş farklı adaylar üretir.")
                        .font(.caption).foregroundStyle(.secondary)
                    Button("Çırak İlanı As • \(store.catalog.balance.apprenticeAdCost.liraText)") {
                        store.send(.postApprenticeAd)
                    }
                    .buttonStyle(ActionButtonStyle(tint: GarageStyle.orange))
                }

                Text("Günlük ücret: kişi başı \(store.catalog.balance.apprenticeDailyWage.liraText)")
                    .font(.caption2).foregroundStyle(.secondary)
            }
        }
        .garageCard()
    }

    private func applicationCard(_ application: ApprenticeApplication) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(application.name).font(.subheadline.bold())
                    Text(application.background.title)
                        .font(.caption2).foregroundStyle(GarageStyle.orange)
                }
                Spacer()
                Text(experienceTitle(application.startingExperience))
                    .font(.caption2.bold())
                    .foregroundStyle(GarageStyle.mint)
            }
            Text(application.introduction)
                .font(.caption).foregroundStyle(.white.opacity(0.82))
            HStack(spacing: 8) {
                Button("Reddet") {
                    store.send(.rejectApprenticeApplication(application.id))
                }
                .buttonStyle(ActionButtonStyle(tint: GarageStyle.raised, foreground: .white))
                Button("Kabul Et") {
                    store.send(.acceptApprenticeApplication(application.id))
                }
                .buttonStyle(ActionButtonStyle(tint: GarageStyle.mint))
            }
        }
        .padding(10)
        .background(.black.opacity(0.2), in: RoundedRectangle(cornerRadius: 12))
    }

    private var currentShop: ShopLevelDefinition? {
        store.catalog.shopLevel(store.state.shopLevel)
    }

    private var availableSlots: Int {
        max(0, (currentShop?.maxApprentices ?? 0) - store.state.apprentices.count)
    }

    private func experienceTitle(_ experience: Int) -> String {
        switch experience {
        case ...20: "Tecrübesiz"
        case 21...60: "Temel bilgili"
        default: "Staj tecrübeli"
        }
    }
}
