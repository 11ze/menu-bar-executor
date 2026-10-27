import SwiftUI

struct SettingsView: View {
    @State private var tab = 0

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 2) {
                tabButton("命令", index: 0)
                tabButton("通用", index: 1)
            }
            .padding(3)
            .background(Color.primary.opacity(0.06))
            .clipShape(Capsule())
            .padding(16)
            .frame(maxWidth: .infinity)
            .background(InterfaceStyle.material)

            if tab == 0 { CommandsListView() }
            else { GeneralSettingsView() }
        }
        .font(.system(size: 13))
        .foregroundColor(InterfaceStyle.text)
        .background(InterfaceStyle.surface)
        .frame(minWidth: 640, idealWidth: 840, minHeight: 420, idealHeight: 620, maxHeight: 620)
    }

    private func tabButton(_ title: String, index: Int) -> some View {
        Button { tab = index } label: {
            Text(title).frame(width: 84, height: 30)
                .foregroundColor(tab == index ? InterfaceStyle.text : InterfaceStyle.muted)
                .background(tab == index ? InterfaceStyle.surface : .clear)
                .clipShape(Capsule())
                .contentShape(Capsule())
        }.buttonStyle(.plain).accessibilityAddTraits(tab == index ? .isSelected : [])
    }
}
