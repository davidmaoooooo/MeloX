import SwiftUI
import UniformTypeIdentifiers

struct DesktopThirdPartySourceSettingsView: View {
    @State private var sources = ThirdPartySourceStore.shared.sources
    @State private var isEnabled = ThirdPartySourceStore.shared.isEnabled
    @State private var remoteURL = ""
    @State private var remoteName = ""
    @State private var showsImporter = false
    @State private var errorMessage: String?

    var body: some View {
        Form {
            Section("第三方音源") {
                Toggle("启用第三方音源", isOn: Binding(
                    get: { isEnabled },
                    set: {
                        isEnabled = $0
                        ThirdPartySourceStore.shared.isEnabled = $0
                    }
                ))
                Text("仅歌曲播放地址使用已启用的音源；搜索、歌单、登录、歌词和其他接口保持不变。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("添加音源") {
                Button {
                    showsImporter = true
                } label: {
                    Label("导入音源脚本文件", systemImage: "doc.badge.plus")
                }

                TextField("音源地址（JS 文件 URL）", text: $remoteURL)
                    .textFieldStyle(.roundedBorder)
                TextField("名称（可选）", text: $remoteName)
                    .textFieldStyle(.roundedBorder)
                Button {
                    addRemoteSource()
                } label: {
                    Label("添加远程音源", systemImage: "link.badge.plus")
                }
                .disabled(URL(string: remoteURL.trimmingCharacters(in: .whitespacesAndNewlines))?.scheme == nil)
            }

            Section("已配置音源") {
                if sources.isEmpty {
                    Text("暂无音源，请导入脚本或添加远程地址。")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(sources) { source in
                        HStack(spacing: 10) {
                            Image(systemName: source.enabled ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(source.enabled ? .green : .secondary)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(source.name)
                                Text(source.localFileName != nil ? "本地脚本" : (source.scriptURL?.absoluteString ?? "远程脚本"))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                            Spacer()
                            if !source.enabled {
                                Button("启用") { enable(source) }
                                    .buttonStyle(.bordered)
                            }
                            Button(role: .destructive) { remove(source) } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                }
            }
        }
        .formStyle(.columns)
        .padding()
        .fileImporter(
            isPresented: $showsImporter,
            allowedContentTypes: [UTType(filenameExtension: "js") ?? .plainText, .plainText, .data],
            allowsMultipleSelection: false
        ) { result in
            importFile(result)
        }
        .alert("音源配置失败", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("确定", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func importFile(_ result: Result<[URL], Error>) {
        do {
            guard let url = try result.get().first else { return }
            let accessed = url.startAccessingSecurityScopedResource()
            defer { if accessed { url.stopAccessingSecurityScopedResource() } }
            let data = try Data(contentsOf: url)
            _ = try ThirdPartySourceStore.shared.importScript(data: data, fileName: url.lastPathComponent)
            reload()
        } catch { errorMessage = error.localizedDescription }
    }

    private func addRemoteSource() {
        guard let url = URL(string: remoteURL.trimmingCharacters(in: .whitespacesAndNewlines)),
              ["http", "https"].contains(url.scheme?.lowercased()) else { return }
        _ = ThirdPartySourceStore.shared.addRemote(url: url, name: remoteName)
        remoteURL = ""
        remoteName = ""
        reload()
    }

    private func enable(_ source: ThirdPartySource) {
        ThirdPartySourceStore.shared.setEnabled(source)
        isEnabled = true
        reload()
    }

    private func remove(_ source: ThirdPartySource) {
        ThirdPartySourceStore.shared.remove(source)
        reload()
    }

    private func reload() {
        ThirdPartySourceStore.shared.reload()
        sources = ThirdPartySourceStore.shared.sources
        isEnabled = ThirdPartySourceStore.shared.isEnabled
        ThirdPartySourceRuntime.shared.clear()
    }
}
