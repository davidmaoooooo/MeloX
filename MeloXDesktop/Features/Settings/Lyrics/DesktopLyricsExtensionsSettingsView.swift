import SwiftUI

struct DesktopLyricsExtensionsSettingsView: View {
    @Environment(DesktopAppModel.self) private var model
    @State private var showsNotificationPermissionAlert = false

    var body: some View {
        @Bindable var floating = model.settings.floatingLyrics
        @Bindable var notifications = model.settings.lyricsNotifications

        ScrollView {
            Form {
                Section("桌面歌词") {
                    Toggle(
                        "显示翻译",
                        isOn: $floating.showsTranslation
                    )
                    Toggle(
                        "显示下一行",
                        isOn: $floating.showsNextLine
                    )
                    Picker(
                        "文字对齐",
                        selection: $floating.textAlignment
                    ) {
                        ForEach(FloatingLyricsTextAlignment.allCases) {
                            alignment in
                            Text(alignment.title)
                                .tag(alignment)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("文字样式") {
                    Picker("字重", selection: $floating.fontWeight) {
                        ForEach(LyricsFontWeight.allCases) { weight in
                            Text(weight.title)
                                .tag(weight)
                        }
                    }
                    Picker("文字效果", selection: $floating.textEffect) {
                        ForEach(FloatingLyricsTextEffect.allCases) { effect in
                            Text(effect.title)
                                .tag(effect)
                        }
                    }
                    .pickerStyle(.segmented)
                    HStack {
                        Text("歌词大小")
                        Slider(
                            value: $floating.fontScale,
                            in: FloatingLyricsPreferences.fontScaleRange,
                            step: 0.05
                        )
                        Text(
                            "\(Int((floating.fontScale * 100).rounded()))%"
                        )
                        .monospacedDigit()
                        .frame(width: 48, alignment: .trailing)
                    }
                    percentageSlider(
                        "文字不透明度",
                        value: $floating.textOpacity,
                        range: FloatingLyricsPreferences.textOpacityRange
                    )
                    valueSlider(
                        "行间距",
                        value: $floating.lineSpacing,
                        range: FloatingLyricsPreferences.lineSpacingRange,
                        suffix: " pt"
                    )
                }

                Section("背景") {
                    Picker("背景样式", selection: $floating.backgroundStyle) {
                        ForEach(FloatingLyricsBackgroundStyle.allCases) {
                            style in
                            Text(style.title)
                                .tag(style)
                        }
                    }
                    percentageSlider(
                        "背景强度",
                        value: $floating.backgroundOpacity,
                        range: FloatingLyricsPreferences.backgroundOpacityRange
                    )
                    .disabled(floating.backgroundStyle == .transparent)
                    if floating.backgroundStyle == .blurredArtwork {
                        valueSlider(
                            "封面模糊",
                            value: $floating.backgroundBlur,
                            range: FloatingLyricsPreferences.backgroundBlurRange,
                            suffix: " pt"
                        )
                    }
                    valueSlider(
                        "窗口圆角",
                        value: $floating.cornerRadius,
                        range: FloatingLyricsPreferences.cornerRadiusRange,
                        suffix: " pt"
                    )
                    LabeledContent("窗口大小") {
                        Text("拖动窗口边缘调整")
                            .foregroundStyle(.secondary)
                    }
                }

                Section("歌词通知") {
                    Toggle(
                        "启用歌词通知",
                        isOn: notificationEnabledBinding
                    )
                    Toggle(
                        "显示封面",
                        isOn: $notifications.showsArtwork
                    )
                    Toggle(
                        "前台显示",
                        isOn: $notifications.showsInForeground
                    )
                    Toggle(
                        "后台显示",
                        isOn: $notifications.showsInBackground
                    )
                    Toggle(
                        "暂停时移除",
                        isOn: $notifications.removesWhenPaused
                    )
                }
            }
            .formStyle(.columns)
            .padding()
        }
        .scrollIndicators(.automatic)
        .onChange(of: notifications.showsArtwork) { _, _ in
            model.player.applyLyricsNotificationPreference()
        }
        .onChange(of: notifications.showsInForeground) { _, _ in
            model.player.applyLyricsNotificationPreference()
        }
        .onChange(of: notifications.showsInBackground) { _, _ in
            model.player.applyLyricsNotificationPreference()
        }
        .onChange(of: notifications.removesWhenPaused) { _, _ in
            model.player.applyLyricsNotificationPreference()
        }
        .alert(
            "无法开启通知歌词",
            isPresented: $showsNotificationPermissionAlert
        ) {
            Button("好", role: .cancel) {}
        } message: {
            Text("请先在系统设置中允许 MeloX 显示通知。")
        }
    }

    private func percentageSlider(
        _ title: String,
        value: Binding<Double>,
        range: ClosedRange<Double>
    ) -> some View {
        HStack {
            Text(title)
            Slider(value: value, in: range, step: 0.05)
            Text("\(Int((value.wrappedValue * 100).rounded()))%")
                .monospacedDigit()
                .frame(width: 48, alignment: .trailing)
        }
    }

    private func valueSlider(
        _ title: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        suffix: String
    ) -> some View {
        HStack {
            Text(title)
            Slider(value: value, in: range, step: 1)
            Text("\(Int(value.wrappedValue.rounded()))\(suffix)")
                .monospacedDigit()
                .frame(width: 56, alignment: .trailing)
        }
    }

    private var notificationEnabledBinding: Binding<Bool> {
        Binding(
            get: {
                model.settings.lyricsNotifications.isEnabled
            },
            set: { isEnabled in
                if !isEnabled {
                    model.settings.lyricsNotifications.isEnabled = false
                    model.player.applyLyricsNotificationPreference()
                    return
                }

                Task { @MainActor in
                    guard await model.lyricsNotifications
                        .requestAuthorization() else {
                        model.settings.lyricsNotifications.isEnabled = false
                        showsNotificationPermissionAlert = true
                        return
                    }
                    model.settings.lyricsNotifications.isEnabled = true
                    model.player.applyLyricsNotificationPreference()
                }
            }
        )
    }
}
