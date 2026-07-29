import SwiftUI

struct ContentSettingsView: View {
    @Environment(AppSettings.self) private var settings

    var body: some View {
        @Bindable var settings = settings
        @Bindable var recognition = settings.songRecognition

        Form {
            Section("发现内容") {
                Picker("新碟地区", selection: $settings.musicArea) {
                    Text("全部").tag("ALL")
                    Text("华语").tag("ZH")
                    Text("欧美").tag("EA")
                    Text("韩国").tag("KR")
                    Text("日本").tag("JP")
                }

                Toggle("显示歌单播放量", isOn: $settings.showPlayCount)
            }

            Section {
                Picker(
                    "识别时长",
                    selection: $recognition.duration
                ) {
                    ForEach(
                        SongRecognitionDuration.allCases
                    ) { duration in
                        Text(
                            "\(duration.title) · \(duration.detail)"
                        )
                        .tag(duration)
                    }
                }
            } header: {
                Text("听歌识曲")
            } footer: {
                if recognition.duration.isContinuous {
                    Text("持续识别会不断录音并追加识别结果，直到手动停止。原始录音不会上传，只发送设备端生成的音频指纹。")
                } else {
                    Text("识别到结果后会立即停止；未识别到时会在达到所选时限后结束。原始录音不会上传，只发送设备端生成的音频指纹。")
                }
            }
        }
        .navigationTitle("发现与识曲")
        .navigationBarTitleDisplayMode(.inline)
    }
}
