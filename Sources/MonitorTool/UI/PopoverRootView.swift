import SwiftUI

struct PopoverRootView: View {
    @State private var showingSettings = false

    var body: some View {
        VStack(spacing: 0) {
            dragHandle

            Group {
                if showingSettings {
                    SettingsView(isPresented: $showingSettings)
                } else {
                    DashboardView(showingSettings: $showingSettings)
                }
            }
            .frame(width: 340, height: 460)
        }
        .frame(width: 340, height: 480)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(.secondary.opacity(0.18), lineWidth: 1)
        )
    }

    private var dragHandle: some View {
        ZStack {
            WindowDragHandle()

            Capsule()
                .fill(.secondary.opacity(0.32))
                .frame(width: 44, height: 4)
        }
        .frame(width: 340, height: 20)
        .background(.regularMaterial)
    }
}
