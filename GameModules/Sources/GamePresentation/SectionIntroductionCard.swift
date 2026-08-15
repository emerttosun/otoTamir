import SwiftUI

struct SectionIntroductionCard: View {
    let section: GameSection
    let dismiss: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 11) {
            Image(systemName: section.icon)
                .font(.headline)
                .foregroundStyle(GarageStyle.orange)
                .frame(width: 26)
            VStack(alignment: .leading, spacing: 4) {
                Text("\(section.title) ne işe yarar?")
                    .font(.subheadline.bold())
                Text(section.introduction)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 4)
            Button(action: dismiss) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Sekme tanıtımını kapat")
        }
        .padding(12)
        .background(GarageStyle.panel, in: RoundedRectangle(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .stroke(GarageStyle.orange.opacity(0.45), lineWidth: 1)
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 7)
        .accessibilityElement(children: .contain)
    }
}
