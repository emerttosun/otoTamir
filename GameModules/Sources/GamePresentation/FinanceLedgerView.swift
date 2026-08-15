import GameDomain
import SwiftUI

struct FinanceLedgerView: View {
    let state: GameState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    balanceCard
                    entriesCard
                }
                .padding(12)
            }
            .background(GarageStyle.background.ignoresSafeArea())
            .foregroundStyle(.white)
            .navigationTitle("Kasa Hareketleri")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Kapat") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private var balanceCard: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("GÜNCEL KASA").font(.caption2.bold()).foregroundStyle(GarageStyle.orange)
            Text(state.cash.liraText).font(.largeTitle.bold().monospacedDigit())
            Text("Kira, faturalar, sarf, parça, ücretler, kredi ve satış gelirleri ayrı kalemler halinde tutulur.")
                .font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .garageCard()
    }

    private var entriesCard: some View {
        VStack(alignment: .leading, spacing: 11) {
            if state.financeEntries.isEmpty {
                Text("Henüz kayıtlı kasa hareketi yok.")
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                ForEach(state.financeEntries.reversed()) { entry in
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: entry.amount >= .zero ? "arrow.down.left.circle.fill" : "arrow.up.right.circle.fill")
                            .foregroundStyle(entry.amount >= .zero ? GarageStyle.mint : GarageStyle.danger)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(entry.category.title).font(.subheadline.bold())
                            Text(entry.note).font(.caption2).foregroundStyle(.secondary)
                            Text("Gün \(entry.day)").font(.caption2).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(entry.amount.liraText)
                            .font(.caption.bold().monospacedDigit())
                            .foregroundStyle(entry.amount >= .zero ? GarageStyle.mint : GarageStyle.danger)
                    }
                    if entry.id != state.financeEntries.first?.id {
                        Divider().overlay(.white.opacity(0.1))
                    }
                }
            }
        }
        .garageCard()
    }
}
