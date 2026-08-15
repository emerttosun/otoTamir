import GameDomain
import Foundation
import SwiftUI

public struct RootGameView: View {
    @ObservedObject private var store: GameStore
    @State private var selectedSection = GameSection.workshop
    @State private var showingFinance = false

    public init(store: GameStore) {
        self.store = store
        let qaSection = ProcessInfo.processInfo.environment["OTOTAMIR_QA_SECTION"]
        _selectedSection = State(initialValue: GameSection(rawValue: qaSection ?? "") ?? .workshop)
        #if DEBUG
        _showingFinance = State(initialValue: ProcessInfo.processInfo.environment["OTOTAMIR_QA_SHOW_FINANCE"] == "1")
        #endif
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                StatusBar(state: store.state) {
                    showingFinance = true
                }
                sectionPicker
                Group {
                    switch selectedSection {
                    case .workshop:
                        WorkshopView(store: store)
                    case .auction:
                        AuctionView(store: store)
                    case .listings:
                        ListingsView(store: store)
                    case .progress:
                        ProgressViewScreen(store: store)
                    case .apprentices:
                        ApprenticesView(store: store)
                    case .bank:
                        BankView(store: store)
                    case .store:
                        ShopStoreView(store: store)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .background(GarageStyle.background.ignoresSafeArea())
            .foregroundStyle(.white)
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showingFinance) {
            FinanceLedgerView(state: store.state)
                .presentationDetents([.medium, .large])
        }
        .gameplayFeedback(trigger: store.state.revision)
        .task { await store.start() }
        .overlay(alignment: .top) {
            if let message = store.errorMessage ?? store.bannerMessage {
                InGameNotice(
                    message: message,
                    isError: store.errorMessage != nil
                ) {
                    store.errorMessage = nil
                    store.bannerMessage = nil
                }
                .padding(.horizontal, 14)
                .padding(.top, 72)
                .transition(.move(edge: .top).combined(with: .opacity))
                .zIndex(20)
                .task(id: message) {
                    guard store.errorMessage == nil else { return }
                    try? await Task.sleep(for: .seconds(7))
                    if store.bannerMessage == message {
                        withAnimation { store.bannerMessage = nil }
                    }
                }
            }
        }
        .animation(.spring(response: 0.32), value: store.bannerMessage)
        .animation(.spring(response: 0.32), value: store.errorMessage)
        .overlay {
            if store.isBusy {
                ZStack {
                    Color.black.opacity(0.28).ignoresSafeArea()
                    ProgressView().controlSize(.large).tint(GarageStyle.orange)
                }
            }
        }
        .confirmationDialog("İki farklı dükkân kaydı bulundu", isPresented: conflictBinding, titleVisibility: .visible) {
            if let conflict = store.cloudConflict {
                Button("Bu cihazı kullan • Gün \(conflict.local.day)") {
                    Task { await store.resolveCloudConflict(useRemote: false) }
                }
                Button("iCloud'u kullan • Gün \(conflict.remote.day)") {
                    Task { await store.resolveCloudConflict(useRemote: true) }
                }
            }
            Button("Şimdilik karar verme", role: .cancel) { store.cloudConflict = nil }
        } message: {
            if let conflict = store.cloudConflict {
                Text("Bu cihaz: \(conflict.local.cash.liraText) • iCloud: \(conflict.remote.cash.liraText)")
            }
        }
    }

    private var sectionPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(GameSection.allCases) { section in
                    Button {
                        selectedSection = section
                    } label: {
                        VStack(spacing: 3) {
                            Image(systemName: section.icon)
                                .font(.system(size: 14, weight: .bold))
                            Text(section.title)
                                .font(.system(size: 10, weight: .bold))
                                .lineLimit(1)
                        }
                        .frame(width: 76)
                        .padding(.vertical, 7)
                        .foregroundStyle(selectedSection == section ? Color.black : Color.white.opacity(0.72))
                        .background(selectedSection == section ? GarageStyle.orange : GarageStyle.raised, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(selectedSection == section ? .isSelected : [])
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
    }

    private var conflictBinding: Binding<Bool> {
        Binding(get: { store.cloudConflict != nil }, set: { if !$0 { store.cloudConflict = nil } })
    }
}

private enum GameSection: String, CaseIterable, Identifiable {
    case workshop
    case auction
    case listings
    case progress
    case apprentices
    case bank
    case store

    var id: String { rawValue }
    var title: String {
        switch self {
        case .workshop: "Dükkân"
        case .auction: "İhale"
        case .listings: "İlanlar"
        case .progress: "Gelişim"
        case .apprentices: "Çıraklar"
        case .bank: "Banka"
        case .store: "Mağaza"
        }
    }
    var icon: String {
        switch self {
        case .workshop: "wrench.and.screwdriver.fill"
        case .auction: "car.side.rear.open.fill"
        case .listings: "rectangle.and.pencil.and.ellipsis"
        case .progress: "chart.line.uptrend.xyaxis"
        case .apprentices: "person.2.fill"
        case .bank: "building.columns.fill"
        case .store: "bag.fill"
        }
    }
}

private struct StatusBar: View {
    let state: GameState
    let showFinance: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: showFinance) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("USTANIN YERİ")
                        .font(.caption2.weight(.black))
                        .foregroundStyle(GarageStyle.orange)
                    HStack(spacing: 5) {
                        Text(state.cash.liraText)
                            .font(.headline.monospacedDigit().weight(.bold))
                            .minimumScaleFactor(0.7)
                        Image(systemName: "chevron.right.circle.fill")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            .buttonStyle(.plain)
            .accessibilityHint("Kasa hareketlerini açar")
            Spacer()
            statusPill(icon: "star.fill", text: state.shopRatingText)
        }
        .padding(.horizontal, 15)
        .padding(.vertical, 10)
        .accessibilityElement(children: .combine)
    }

    private func statusPill(icon: String, text: String) -> some View {
        Label(text, systemImage: icon)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 9)
            .padding(.vertical, 7)
            .background(GarageStyle.raised, in: Capsule())
    }
}

private struct InGameNotice: View {
    let message: String
    let isError: Bool
    let dismiss: () -> Void

    var body: some View {
        Button(action: dismiss) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: isError ? "exclamationmark.triangle.fill" : "wrench.and.screwdriver.fill")
                    .foregroundStyle(isError ? GarageStyle.danger : GarageStyle.orange)
                Text(message)
                    .font(.subheadline.weight(.semibold))
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "xmark")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
            }
            .padding(13)
            .foregroundStyle(.white)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14).stroke((isError ? GarageStyle.danger : GarageStyle.orange).opacity(0.55))
            }
            .shadow(color: .black.opacity(0.35), radius: 12, y: 5)
        }
        .buttonStyle(.plain)
        .accessibilityHint("Kapatmak için dokun")
    }
}
