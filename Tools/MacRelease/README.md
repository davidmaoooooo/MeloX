# MeloX macOS 本地签名公证

GitHub Actions 继续发布未签名 DMG。网盘发布使用本工具生成的 `build/MeloX-macOS-notarized.dmg`，只有脚本完成 Developer ID 签名、Apple 公证、票据装订和 Gatekeeper 验证后才会写入该输出。

## 前置条件

- 登录钥匙串已导入 `Developer ID Application` 证书及其私钥。
- App Store Connect API `.p8` 可用于公证。默认会复用 `Tools/TestFlightUploader/.credentials/AuthKey_*.p8`，并从本地 TestFlight 脚本读取 Key ID 和 Issuer ID。
- 也可使用 `ASC_PRIVATE_KEY_PATH`、`ASC_KEY_ID`、`ASC_ISSUER_ID`，或通过命令行参数覆盖。

`.p8` 是公证 API 凭据，不是 Developer ID 代码签名证书。iOS `.mobileprovision` 中的证书公钥也无法代替 Mac 签名所需的私钥。

## 使用

```bash
python3 Tools/MacRelease/build_macos_release.py --check-only
python3 Tools/MacRelease/build_macos_release.py
```

非交互环境需要显式增加 `--yes`。如果已通过 `notarytool store-credentials` 保存公证凭据，可使用：

```bash
python3 Tools/MacRelease/build_macos_release.py \
  --notary-profile MeloX-notary
```

上传网盘前，确认脚本最后输出“已生成 Developer ID 签名、Apple 公证并装订票据的 DMG”。
