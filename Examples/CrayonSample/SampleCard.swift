import SwiftUI

struct SampleCard<Artwork: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder let artwork: () -> Artwork

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline)
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }
            artwork()
                .frame(maxWidth: .infinity)
                .frame(height: 155)
                .background(.white, in: RoundedRectangle(cornerRadius: 16))
                .accessibilityLabel(title)
        }
        .padding(16)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 20))
    }
}
