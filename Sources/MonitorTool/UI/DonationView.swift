import AppKit
import SwiftUI

struct DonationView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("打赏作者")
                        .font(.system(size: 17, weight: .semibold))
                    Text("如果此工具对你有所帮助，你可以通过打赏表达对作者的肯定。")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .semibold))
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
            }

            if let image = donationImage {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 230, height: 313)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.secondary.opacity(0.16), lineWidth: 1)
                    )
            } else {
                Text("收款码加载失败")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .frame(width: 230, height: 313)
            }
        }
        .padding(18)
        .frame(width: 300)
        .background(.regularMaterial)
    }

    private var donationImage: NSImage? {
        guard let url = Bundle.module.url(forResource: "donation-wechat", withExtension: "png") else {
            return nil
        }
        return NSImage(contentsOf: url)
    }
}
