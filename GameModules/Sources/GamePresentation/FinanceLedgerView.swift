import GameDomain
import GameLogic
import SwiftUI

struct FinanceLedgerView: View {
    let state: GameState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    summaryCard
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

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("GÜN \(summary.day) ÖZETİ")
                .font(.caption2.bold())
                .foregroundStyle(GarageStyle.orange)
            summaryRow("Gün başı kasa", amount: summary.openingCash)
            Divider().overlay(.white.opacity(0.1))
            summaryRow("Tamir ve satış gelirleri", amount: summary.operatingIncome, tint: GarageStyle.mint)
            summaryRow("Parça ve işletme giderleri", amount: Money(minorUnits: -summary.operatingExpense.minorUnits), tint: GarageStyle.danger)
            summaryRow("İşletme sonucu", amount: summary.operatingResult, emphasized: true)
            Divider().overlay(.white.opacity(0.1))
            summaryRow("Yeni kullanılan kredi", amount: summary.newLoanProceeds)
            summaryRow("Ödenen kredi taksiti", amount: Money(minorUnits: -summary.loanPayments.minorUnits))
            Text("Kredi kasaya girer fakat gelir veya kâr sayılmaz.")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Divider().overlay(.white.opacity(0.1))
            summaryRow("Net nakit değişimi", amount: summary.netCashChange, emphasized: true)
            summaryRow("Güncel kasa", amount: summary.closingCash, emphasized: true)
        }
        .garageCard()
    }

    private var entriesCard: some View {
        VStack(alignment: .leading, spacing: 11) {
            Text("BUGÜNÜN HAREKETLERİ")
                .font(.caption2.bold())
                .foregroundStyle(GarageStyle.orange)
            if summary.entries.isEmpty {
                Text("Bugün henüz kasa hareketi yok.")
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                ForEach(summary.entries.reversed()) { entry in
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: entry.amount >= .zero ? "arrow.down.left.circle.fill" : "arrow.up.right.circle.fill")
                            .foregroundStyle(entry.amount >= .zero ? GarageStyle.mint : GarageStyle.danger)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(entry.category.title).font(.subheadline.bold())
                            Text(entry.note).font(.caption2).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(entry.amount.liraText)
                            .font(.caption.bold().monospacedDigit())
                            .foregroundStyle(entry.amount >= .zero ? GarageStyle.mint : GarageStyle.danger)
                    }
                    if entry.id != summary.entries.first?.id {
                        Divider().overlay(.white.opacity(0.1))
                    }
                }
            }
        }
        .garageCard()
    }

    private var summary: DailyFinanceSummary {
        DailyFinanceRules.summary(for: state)
    }

    private func summaryRow(
        _ title: String,
        amount: Money,
        tint: Color? = nil,
        emphasized: Bool = false
    ) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(amount.liraText)
                .monospacedDigit()
                .foregroundStyle(tint ?? (amount < .zero ? GarageStyle.danger : .white))
        }
        .font(emphasized ? .subheadline.bold() : .caption)
    }
}
