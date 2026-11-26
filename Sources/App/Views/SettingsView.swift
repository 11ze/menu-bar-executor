import SwiftUI

struct SettingsView: View {
    @ObservedObject private var navigation = SettingsNavigationState.shared
    @State private var tab = 0

    var body: some View {
        VStack(spacing: 0) {
            WindowHeader(title: "设置", selectedTab: $tab)
            if tab == 0 { CommandsListView() }
            else { GeneralSettingsView() }
        }
        .font(.system(size: 13))
        .foregroundColor(InterfaceStyle.text)
        .background(InterfaceStyle.surface)
        .clipShape(RoundedRectangle(cornerRadius: 15))
        .frame(minWidth: 640, idealWidth: 900, minHeight: 420, idealHeight: 640)
        .ignoresSafeArea(edges: .top)
        .onAppear { consumeRequestedTab() }
        .onChange(of: navigation.requestedTab) { _ in consumeRequestedTab() }
    }

    private func consumeRequestedTab() {
        guard let target = navigation.requestedTab else { return }
        tab = target
        navigation.requestedTab = nil
    }
}
