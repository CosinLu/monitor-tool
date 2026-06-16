import SwiftUI

struct MetricSectionView<Content: View>: View {
    let title: String
    let icon: String
    let color: Color
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.system(size: 12, weight: .semibold))
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.primary)
                Spacer()
            }

            content
        }
        .padding(10)
        .background(Color.secondary.opacity(0.08))
        .cornerRadius(8)
    }
}
