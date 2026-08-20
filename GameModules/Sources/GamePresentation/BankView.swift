import GameDomain
import GameLogic
import SwiftUI

struct BankView: View {
    @ObservedObject var store: GameStore
    @State private var selectedPlan: LoanPlan = .standard
    @State private var requestedLira = 50_000.0

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                header
                creditCard
                activeLoansCard
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("SANAYİ ESNAF BANKASI")
                .font(.caption.weight(.black)).foregroundStyle(GarageStyle.orange)
            Text("Araç yatırım kredisi").font(.title3.bold())
            Text("Hasarlı araç almak veya dükkânı büyütmek için kredi kullan. Taksitler yalnız oyun içi işlemler zamanı ilerlettiğinde tahsil edilir.")
                .font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .garageCard()
    }

    private var creditCard: some View {
        let limit = BankingRules.creditLimit(for: store.state)
        let available = BankingRules.availableCredit(for: store.state)
        let maximumLira = max(10_000, Double(available.minorUnits) / 100)
        let selectedLira = min(maximumLira, max(10_000, requestedLira))
        let amount = Money(minorUnits: Int64(selectedLira * 100))
        let total = BankingRules.totalRepayment(for: amount, plan: selectedPlan)
        let installment = BankingRules.installmentAmount(for: amount, plan: selectedPlan)

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                valueBlock("Kredi limiti", value: limit.liraText, tint: .white)
                Spacer()
                valueBlock("Kullanılabilir", value: available.liraText, tint: GarageStyle.mint)
            }

            if available >= Money(minorUnits: 1_000_000) {
                Picker("Vade", selection: $selectedPlan) {
                    ForEach(LoanPlan.allCases, id: \.self) { plan in
                        Text(plan.title).tag(plan)
                    }
                }
                .pickerStyle(.segmented)

                Slider(value: $requestedLira, in: 10_000...maximumLira, step: 5_000)
                    .tint(GarageStyle.orange)
                    .accessibilityLabel("Kredi tutarı")
                HStack {
                    Text("Kredi: \(amount.liraText)")
                    Spacer()
                    Text("Toplam: \(total.liraText)")
                }
                .font(.caption.bold().monospacedDigit())
                Text("\(selectedPlan.interestText) toplam faiz • \(selectedPlan.installmentCount) taksit • her \(selectedPlan.installmentIntervalDays) oyun gününde \(installment.liraText)")
                    .font(.caption2).foregroundStyle(.secondary)
                Button("Krediyi Kullan") {
                    store.send(.takeLoan(amount: amount, plan: selectedPlan))
                }
                .buttonStyle(ActionButtonStyle(tint: GarageStyle.orange))
            } else {
                Text("Mevcut borç azaldıkça kredi limitin yeniden açılır.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .garageCard()
    }

    private var activeLoansCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Aktif Krediler", systemImage: "creditcard.fill").font(.headline)
            if store.state.loans.isEmpty {
                Text("Aktif kredi bulunmuyor.").font(.caption).foregroundStyle(.secondary)
            } else {
                ForEach(store.state.loans) { loan in
                    VStack(alignment: .leading, spacing: 5) {
                        HStack {
                            Text(loan.plan.title).font(.subheadline.bold())
                            Spacer()
                            Text("Kalan \(loan.remainingBalance.liraText)")
                                .font(.caption.bold().monospacedDigit())
                        }
                        Text("\(loan.remainingInstallments) taksit • sıradaki ödeme \(paymentDistance(loan)) sonra • \(loan.installmentAmount.liraText)")
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                    .padding(10)
                    .background(GarageStyle.raised.opacity(0.7), in: RoundedRectangle(cornerRadius: 11))
                }
            }
        }
        .garageCard()
    }

    private func valueBlock(_ title: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.caption2).foregroundStyle(.secondary)
            Text(value).font(.subheadline.bold().monospacedDigit()).foregroundStyle(tint)
        }
    }

    private func paymentDistance(_ loan: BankLoan) -> String {
        let minutes = max(0, loan.nextPaymentMinute - store.state.totalMinutes)
        let days = max(1, (minutes + 1_439) / 1_440)
        return "\(days) oyun günü"
    }
}
