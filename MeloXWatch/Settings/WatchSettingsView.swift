import SwiftUI

struct WatchSettingsView: View {
    var body: some View {
        List {
            Section("播放器") {
                NavigationLink {
                    WatchAudioSettingsView()
                } label: {
                    Label("音质与音量", systemImage: "speaker.wave.2")
                }

                NavigationLink {
                    WatchPlaybackBehaviorSettingsView()
                } label: {
                    Label("播放行为", systemImage: "repeat")
                }

                NavigationLink {
                    WatchPlayerAppearanceSettingsView()
                } label: {
                    Label("播放器外观", systemImage: "rectangle.inset.filled")
                }
            }

            Section("歌词") {
                NavigationLink {
                    WatchLyricsSettingsView()
                } label: {
                    Label("歌词显示与动效", systemImage: "quote.bubble")
                }
            }
        }
        .navigationTitle("设置")
    }
}
