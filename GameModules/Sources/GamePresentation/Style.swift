import SwiftUI

enum GarageStyle {
    static let background = Color(red: 0.075, green: 0.08, blue: 0.09)
    static let panel = Color(red: 0.13, green: 0.14, blue: 0.15)
    static let raised = Color(red: 0.19, green: 0.20, blue: 0.20)
    static let orange = Color(red: 0.94, green: 0.53, blue: 0.18)
    static let mint = Color(red: 0.34, green: 0.76, blue: 0.61)
    static let danger = Color(red: 0.88, green: 0.30, blue: 0.27)
}

struct GarageCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(14)
            .background(GarageStyle.panel, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(.white.opacity(0.07), lineWidth: 1)
            }
    }
}

extension View {
    func garageCard() -> some View { modifier(GarageCardModifier()) }

    @ViewBuilder
    func gameplayFeedback(trigger: Int) -> some View {
#if os(iOS)
        sensoryFeedback(.impact(weight: .light), trigger: trigger)
#else
        self
#endif
    }
}

struct ActionButtonStyle: ButtonStyle {
    let tint: Color

    init(tint: Color = GarageStyle.orange) {
        self.tint = tint
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.bold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 11)
            .foregroundStyle(Color.black.opacity(0.82))
            .background(tint.opacity(configuration.isPressed ? 0.65 : 1), in: RoundedRectangle(cornerRadius: 11))
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}
