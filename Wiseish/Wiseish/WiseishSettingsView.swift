import SwiftUI
import UserNotifications
import UIKit

struct WiseishSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("notification.daily.enabled") private var notificationEnabled = false
    @AppStorage("notification.daily.hour") private var notificationHour = 8
    @AppStorage("notification.daily.minute") private var notificationMinute = 0
    @State private var notificationTime = Date.now
    @State private var permissionDenied = false
    @State private var isUpdatingNotification = false

    let onShowWidgetGuide: () -> Void

    private let paper = Color(red: 0.96, green: 0.92, blue: 0.85)
    private let lightPaper = Color(red: 1.00, green: 0.98, blue: 0.94)
    private let ink = Color(red: 0.16, green: 0.15, blue: 0.13)
    private let softInk = Color(red: 0.44, green: 0.41, blue: 0.37)
    private let mustard = Color(red: 0.85, green: 0.66, blue: 0.23)

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
                    Text("一日一度、Ishが呼びにくる")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(softInk)
                }

                Spacer()

                Toggle("", isOn: notificationBinding)
                    .labelsHidden()
                    .tint(mustard)
                    .disabled(isUpdatingNotification)
            }

            if notificationEnabled {
                Divider().overlay(ink.opacity(0.1))

                HStack {
                    Text("呼びにくる時刻")
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

            Text("迷言は通知に全部出さぬ。開く余地も残しておく。")
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
                Text("60枚")
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

            Text("入力した言葉と反応は端末内に置いておく。外へは持ち出さん。")
                .font(.system(size: 9, weight: .medium, design: .serif))
                .lineSpacing(3)
                .foregroundStyle(softInk)
        }
        .padding(16)
        .background(.white.opacity(0.16), in: RoundedRectangle(cornerRadius: 18))
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

#Preview {
    WiseishSettingsView {}
}
