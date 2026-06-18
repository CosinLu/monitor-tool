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
        .frame(width: 340, height: 466)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(.secondary.opacity(0.18), lineWidth: 1)
        )
    }

    private var dragHandle: some View {
        WindowDragHandle()
            .frame(width: 340, height: 6)
        .background(.regularMaterial)
    }
}
