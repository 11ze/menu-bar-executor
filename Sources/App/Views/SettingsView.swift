import SwiftUI

struct SettingsView: View {
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
        .frame(minWidth: 640, idealWidth: 840, minHeight: 420, idealHeight: 549)
        .ignoresSafeArea(edges: .top)
    }
}
