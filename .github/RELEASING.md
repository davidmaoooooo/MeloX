# MeloX 发版规则

## 更新日志

`RELEASE_NOTES.md` 固定包含两个区块：

- `iOS + Apple Watch`：非空时构建并发布 IPA。
- `macOS`：非空时分别构建并发布 Apple Silicon 与 Intel DMG。

普通分支、Pull Request 与 `main` 构建会根据非空区块选择产物。两个区块都有内容时，会分别构建两份产物。

## 标签与版本

- iOS + Apple Watch：`v<major>.<minor>.<patch>`，例如 `v1.2.0`。
- macOS：`v<major>.<minor>.<patch>_mac`，例如 `v0.1.0_mac`。

两端同时发版时，将两个标签指向同一个 Commit 并一起推送。每个标签会独立创建 GitHub Release，并独立发送一条 Telegram 发版消息。

macOS Release 不会替换仓库的 Latest；Latest 始终保留给移动端，以兼容仍请求 `/releases/latest` 的旧版 iOS 客户端。

GitHub Actions 生成 `MeloX-macOS-Apple-Silicon.dmg` 和 `MeloX-macOS-Intel.dmg`，两者仅作为未签名构建发布。GitHub Release 正文和官网 Release 区域保留 Gatekeeper 处理说明；“选择平台下载”下拉菜单只标注“未签名”，不附带 `xattr` 文案。

网盘中的 macOS DMG 使用 `Tools/MacRelease/build_macos_release.py` 在本地生成。Apple Silicon（`arm64`）与 Intel（`x86_64`）分别构建、签名和公证。只有该工具完成两份 DMG 的 Developer ID 签名、Apple 公证、票据装订和 Gatekeeper 验证后，官网网盘入口才标注“已公证”。macOS Telegram 发版消息同时说明，已签名公证版需前往官网获取。
