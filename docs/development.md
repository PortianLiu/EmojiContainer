# 开发说明

面向开发者的运行、签名与 CI 说明。产品功能见根目录 [README.md](../README.md)。

## 技术栈

- Flutter + Material 3
- flutter_bloc 状态管理
- shared_preferences 保存总目录与设置
- file_picker / 系统相册选择器
- Windows：原生 `SHDoDragDrop` 拖拽发送；托盘最小化
- Android：分享接收（`receive_sharing_intent`）、系统分享发送

## 运行

```bash
flutter pub get
flutter run -d windows   # 或其他平台
```

### Windows 桌面拖拽

电脑端使用 Windows 原生 `SHDoDragDrop` 将图片文件拖到微信等聊天窗口。请使用 **Windows 目标** 编译：

```bash
flutter run -d windows
```

### Android / Gradle

- 本地可选：设置环境变量 `GRADLE_USER_HOME` 指向自建 Gradle 缓存（勿写入仓库；CI 使用默认路径）
- `gradlew.bat` 请保持 **ASCII 注释**（避免 CMD 在 GBK 下把中文当成命令执行）
- Release 签名：复制 `android/key.properties.example` 为 `android/key.properties` 并填写 JKS 信息
- 当前 `applicationId` / `namespace`：`lpt.emoji_container`

## CI 自动打包

推送 **`v*` Tag**（如 `v2.9`）后自动构建 Windows 安装包 / 便携包与 Android APK。

### GitHub Actions

- 工作流：`.github/workflows/build-and-release.yml`
- 产物示例：
  - `EmojiContainer_Setup_x64_v2.9.exe`（Inno Setup 安装包）
  - `EmojiContainer_Win_v2.9.zip` / `.7z`（便携版）
  - `EmojiContainer_Android_v2.9.apk`
- 安装脚本：根目录 `EmojiContainer.iss`（由 CI 调用 `iscc` 编译）
- 在仓库 **Settings → Secrets and variables → Actions** 添加：

| Secret | 说明 |
|--------|------|
| `ANDROID_KEYSTORE_BASE64` | JKS 文件 Base64 |
| `ANDROID_KEYSTORE_PASSWORD` | 密钥库密码 |
| `ANDROID_KEY_ALIAS` | 别名 |
| `ANDROID_KEY_PASSWORD` | 密钥密码 |

生成 Base64（PowerShell）：

```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("C:\Users\PortianLiu\.android\keystores\emoji-container-key.jks")) | Set-Clipboard
```

### Gitee Go

- 流水线：`.workflow/tag-pipeline.yml`（需在仓库中启用 Gitee Go）
- 在 **流水线 → 密钥/变量** 中配置与 GitHub 相同的四个变量名
- 构建完成后可在制品库下载 `build/dist/` 下的安装包、zip/7z 与 apk

安装包由根目录 `EmojiContainer.iss` 生成（已适配本项目插件与 `emoji_container.exe`）。
