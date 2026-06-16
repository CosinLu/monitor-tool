import SwiftUI

struct TrendLineView: View {
    let values: [Double]
    let color: Color

    var body: some View {
        GeometryReader { geometry in
            if values.count >= 2 {
                let width = geometry.size.width
                let height = geometry.size.height
                let minValue = 0.0
                let maxValue = max(values.max() ?? 1.0, 1.0)
                let stepX = width / CGFloat(values.count - 1)

                Path { path in
                    for (index, value) in values.enumerated() {
                        let x = CGFloat(index) * stepX
                        let y = height - CGFloat((value - minValue) / (maxValue - minValue)) * height
                        let point = CGPoint(x: x, y: y)
                        if index == 0 {
                            path.move(to: point)
                        } else {
                            path.addLine(to: point)
                        }
                    }
                }
                .stroke(color, lineWidth: 1.5)
            } else {
                EmptyView()
            }
        }
    }
}
