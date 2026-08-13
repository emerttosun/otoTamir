import GameDomain
import SwiftUI

public struct RootGameView: View {
    @ObservedObject private var store: GameStore
    @State private var selectedSection = GameSection.workshop

    public init(store: GameStore) {
        self.store = store
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                StatusBar(state: store.state)
                sectionPicker
                Group {
                    switch selectedSection {
                    case .workshop:
                        WorkshopView(store: store)
                    case .auction:
                        AuctionView(store: store)
                    case .progress:
                        ProgressViewScreen(store: store)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .background(GarageStyle.background.ignoresSafeArea())
            .foregroundStyle(.white)
        }
        .preferredColorScheme(.dark)
        .gameplayFeedback(trigger: store.state.revision)
        .task { await store.start() }
        .overlay {
            if store.isBusy {
                ZStack {
                    Color.black.opacity(0.28).ignoresSafeArea()
                    ProgressView().controlSize(.large).tint(GarageStyle.orange)
                }
            }
        }
        .alert("Sanayi Haberi", isPresented: bannerBinding) {
            Button("Tamam") { store.bannerMessage = nil }
        } message: {
            Text(store.bannerMessage ?? "")
        }
        .alert("Bir sorun çıktı", isPresented: errorBinding) {
            Button("Tamam") { store.errorMessage = nil }
        } message: {
            Text(store.errorMessage ?? "")
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
        HStack(spacing: 8) {
            ForEach(GameSection.allCases) { section in
                Button {
                    selectedSection = section
                } label: {
                    Label(section.title, systemImage: section.icon)
                        .font(.caption.weight(.bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .foregroundStyle(selectedSection == section ? Color.black : Color.white.opacity(0.72))
                        .background(selectedSection == section ? GarageStyle.orange : GarageStyle.raised, in: Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selectedSection == section ? .isSelected : [])
            }
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
    }

    private var bannerBinding: Binding<Bool> {
        Binding(get: { store.bannerMessage != nil }, set: { if !$0 { store.bannerMessage = nil } })
    }

    private var errorBinding: Binding<Bool> {
        Binding(get: { store.errorMessage != nil }, set: { if !$0 { store.errorMessage = nil } })
    }

    private var conflictBinding: Binding<Bool> {
        Binding(get: { store.cloudConflict != nil }, set: { if !$0 { store.cloudConflict = nil } })
    }
}

private enum GameSection: String, CaseIterable, Identifiable {
    case workshop
    case auction
    case progress

    var id: String { rawValue }
    var title: String {
        switch self {
        case .workshop: "Dükkân"
        case .auction: "İhale"
        case .progress: "Gelişim"
        }
    }
    var icon: String {
        switch self {
        case .workshop: "wrench.and.screwdriver.fill"
        case .auction: "gavel.fill"
        case .progress: "chart.line.uptrend.xyaxis"
        }
    }
}

private struct StatusBar: View {
    let state: GameState

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("USTANIN YERİ")
                    .font(.caption2.weight(.black))
                    .foregroundStyle(GarageStyle.orange)
                Text(state.cash.liraText)
                    .font(.headline.monospacedDigit().weight(.bold))
                    .minimumScaleFactor(0.7)
            }
            Spacer()
            statusPill(icon: "calendar", text: "Gün \(state.day)")
            statusPill(icon: "clock.fill", text: "\(state.remainingSlots)/8")
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
