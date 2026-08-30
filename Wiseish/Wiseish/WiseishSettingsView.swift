import SwiftUI
import UserNotifications
import UIKit

struct WiseishSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("notification.daily.enabled") private var notificationEnabled = false
    @AppStorage("notification.daily.hour") private var notificationHour = 8
    @AppStorage("notification.daily.minute") private var notificationMinute = 0
    @State private var notificationTime = Date.now
    @State private var permissionDenied = false
    @State private var isUpdatingNotification = false

    let onShowWidgetGuide: () -> Void

    private var paper: Color { colorScheme == .dark ? Color(red: 0.10, green: 0.10, blue: 0.09) : Color(red: 0.96, green: 0.92, blue: 0.85) }
    private var lightPaper: Color { colorScheme == .dark ? Color(red: 0.16, green: 0.15, blue: 0.13) : Color(red: 1.00, green: 0.98, blue: 0.94) }
    private var ink: Color { colorScheme == .dark ? Color(red: 0.92, green: 0.89, blue: 0.83) : Color(red: 0.16, green: 0.15, blue: 0.13) }
    private var softInk: Color { colorScheme == .dark ? Color(red: 0.68, green: 0.65, blue: 0.59) : Color(red: 0.44, green: 0.41, blue: 0.37) }
    private let mustard = Color(red: 0.85, green: 0.66, blue: 0.23)
    @State private var store = WiseishStore.shared

    var body: some View {
        NavigationStack {
            ZStack {
                paper.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 14) {
                        notificationCard
                        widgetCard
                        aboutCard
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 18)
                }
            }
            .foregroundStyle(ink)
            .task { await store.load() }
            .navigationTitle("設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("閉じる") { dismiss() }
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(ink)
                }
            }
        }
        .task { await loadNotificationState() }
    }

    private var notificationCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 11) {
                Image(systemName: "bell")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(lightPaper)
                    .frame(width: 34, height: 34)
                    .background(ink, in: Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text("今日のIsh")
                        .font(.system(size: 14, weight: .bold, design: .serif))
                    Text("一日一度、今日の分を置いておく")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(softInk)
                }

                Spacer()

                Toggle("", isOn: notificationBinding)
                    .labelsHidden()
                    .toggleStyle(
                        WiseishToggleStyle(
                            onColor: mustard,
                            offColor: ink.opacity(0.24),
                            thumbColor: lightPaper,
                            outlineColor: ink.opacity(0.38)
                        )
                    )
                    .disabled(isUpdatingNotification)
            }

            if notificationEnabled {
                Divider().overlay(ink.opacity(0.1))

                HStack {
                    Text("置いておく時刻")
                        .font(.system(size: 12, weight: .semibold, design: .serif))
                    Spacer()
                    DatePicker(
                        "通知時刻",
                        selection: $notificationTime,
                        displayedComponents: .hourAndMinute
                    )
                    .labelsHidden()
                    .onChange(of: notificationTime) { _, newValue in
                        updateNotificationTime(newValue)
                    }
                }
            }

            if permissionDenied {
                VStack(alignment: .leading, spacing: 8) {
                    Text("通知がiPhoneの設定でオフになっています。")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(softInk)

                    Button("iPhoneの設定を開く") {
                        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                        UIApplication.shared.open(url)
                    }
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(ink)
                }
            }

            Text("通知は一日一度だけ。いらない日は、いつでも休めます。")
                .font(.system(size: 9, weight: .medium, design: .serif))
                .foregroundStyle(softInk)
        }
        .padding(16)
        .background(lightPaper.opacity(0.62), in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(ink.opacity(0.12), lineWidth: 1))
    }

    private var widgetCard: some View {
        Button {
            dismiss()
            onShowWidgetGuide()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "square.grid.2x2")
                    .font(.system(size: 15, weight: .semibold))
                    .frame(width: 34, height: 34)
                    .background(mustard, in: RoundedRectangle(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Widgetの置き方")
                        .font(.system(size: 13, weight: .bold, design: .serif))
                    Text("ホーム画面にもIshを置く")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(softInk)
                }

                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(softInk)
            }
            .padding(16)
            .background(lightPaper.opacity(0.45), in: RoundedRectangle(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(ink.opacity(0.12), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private var aboutCard: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Text("言葉の棚")
                    .font(.system(size: 12, weight: .bold, design: .serif))
                Spacer()
                Text("\(WiseishCatalogStore.currentCatalog().quotes.count)枚")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(softInk)
            }

            HStack {
                Text("カタログ")
                    .font(.system(size: 11, weight: .medium))
                Spacer()
                Text(WiseishCatalogStore.currentCatalog().catalogVersion)
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundStyle(softInk)
            }

            HStack {
                Text("棚")
                    .font(.system(size: 11, weight: .medium))
                Spacer()
                if store.isUnlocked {
                    Text("解放済み")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(mustard)
                } else {
                    Button("以前の購入を復元する") {
                        Task { await store.restore() }
                    }
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(softInk)
                    .disabled(store.isWorking)
                }
            }

            if let message = store.purchaseMessage {
                Text(message)
                    .font(.system(size: 9, weight: .medium, design: .serif))
                    .foregroundStyle(softInk)
            }

            Text("お気に入りと過去の日々は端末内に置いておきます。")
                .font(.system(size: 9, weight: .medium, design: .serif))
                .lineSpacing(3)
                .foregroundStyle(softInk)
        }
        .padding(16)
        .background(lightPaper.opacity(0.35), in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(ink.opacity(0.1), lineWidth: 1))
    }

    private var notificationBinding: Binding<Bool> {
        Binding(
            get: { notificationEnabled },
            set: { wantsNotification in
                if wantsNotification {
                    enableNotification()
                } else {
                    WiseishNotificationService.cancel()
                    notificationEnabled = false
                    permissionDenied = false
                }
            }
        )
    }

    private func enableNotification() {
        guard !isUpdatingNotification else { return }
        isUpdatingNotification = true
        Task {
            let didSchedule = await WiseishNotificationService.requestAndSchedule(
                hour: notificationHour,
                minute: notificationMinute
            )
            notificationEnabled = didSchedule
            permissionDenied = !didSchedule
            isUpdatingNotification = false
            if didSchedule {
                WiseishContextStore.recordUsage(.notificationEnabled)
            }
        }
    }

    private func loadNotificationState() async {
        let calendar = Calendar.current
        notificationTime = calendar.date(
            bySettingHour: notificationHour,
            minute: notificationMinute,
            second: 0,
            of: .now
        ) ?? .now

        let status = await WiseishNotificationService.authorizationStatus()
        permissionDenied = status == .denied
        if notificationEnabled && status != .authorized && status != .provisional && status != .ephemeral {
            notificationEnabled = false
        }
    }

    private func updateNotificationTime(_ date: Date) {
        let components = Calendar.current.dateComponents([.hour, .minute], from: date)
        notificationHour = components.hour ?? 8
        notificationMinute = components.minute ?? 0
        guard notificationEnabled else { return }

        Task {
            let didSchedule = await WiseishNotificationService.schedule(
                hour: notificationHour,
                minute: notificationMinute
            )
            if !didSchedule {
                notificationEnabled = false
            }
        }
    }
}

private struct WiseishToggleStyle: ToggleStyle {
    let onColor: Color
    let offColor: Color
    let thumbColor: Color
    let outlineColor: Color

    func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            ZStack {
                Capsule()
                    .fill(configuration.isOn ? onColor : offColor)

                Capsule()
                    .stroke(outlineColor, lineWidth: 1)

                Circle()
                    .fill(thumbColor)
                    .frame(width: 24, height: 24)
                    .shadow(color: .black.opacity(0.16), radius: 2, y: 1)
                    .offset(x: configuration.isOn ? 10 : -10)
            }
            .frame(width: 50, height: 30)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .animation(.easeOut(duration: 0.18), value: configuration.isOn)
        .accessibilityValue(configuration.isOn ? "オン" : "オフ")
    }
}

#Preview {
    WiseishSettingsView {}
}
