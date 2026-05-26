# 表情包管理器 (emoji_container)

基于本地文件夹的表情包管理应用。指定一个**总目录**后，其下每个子文件夹会作为一个**表情包集**，以类似手机相册的方式展示。

## 目录结构约定

```
总目录/
├── 零散.png           ← 根目录图片也算一个表情包集
├── 可爱猫猫/          ← 子文件夹（含子目录内的图）
│   ├── 01.png
│   └── 子目录/02.gif
└── 沙雕表情/
    └── happy.jpg
```

- 总目录：在应用中设置，会持久保存
- 根目录下的图片：以总目录名作为表情包集
- 子文件夹：文件夹内（含子目录）所有图片归为一个表情包集
- 支持的图片格式：png、jpg、jpeg、gif、webp、bmp

## 功能

- 浏览选择或手动输入总目录路径
- 相册式网格展示各表情包集（封面为集内第一张图）
- 点击进入查看集内全部表情，支持大图预览与缩放
- 刷新扫描、更改或清除总目录
- **发送表情**：
  - 手机：调起系统分享
  - 电脑：复制到剪贴板（图片 + 文件路径），支持拖拽到聊天窗口

暂未实现：导入、数据库同步等。

## 运行

```bash
flutter pub get
flutter run -d windows   # 或其他平台
```

### Windows 桌面拖拽

电脑端使用 Windows 原生 `SHDoDragDrop` 将图片文件拖到微信等聊天窗口（无需 Rust）。请使用 **Windows 目标** 重新编译：

```bash
flutter run -d windows
```

### Android / Gradle

- 使用本地 Gradle：`A:\WorkSpace\AllSDK\Gradle\user_home`（见 `android/gradle.properties`、`gradlew.bat`）
- `gradlew.bat` 请保持 **ASCII 注释**（避免 CMD 在 GBK 下把中文当成命令执行）
- Release 签名：复制 `android/key.properties.example` 为 `android/key.properties` 并填写 JKS 信息

## CI 自动打包

推送 **`v*` Tag**（如 `v2.3`）后自动构建 Windows 便携包与 Android APK。

### GitHub Actions

- 工作流：`.github/workflows/build-and-release.yml`
- 产物：`EmojiContainer_Win_vX.Y.zip`、`EmojiContainer_Android_vX.Y.apk`（发布到 GitHub Release）
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
- 构建完成后可在制品库下载 `build/dist/` 下的 zip 与 apk

与 TodoMatrix 参考配置的差异：本项目**无 Inno Setup 安装包**，Windows 仅发布 zip 便携版。

## 技术栈

- Flutter + Material 3
- flutter_bloc 状态管理
- shared_preferences 保存总目录路径
- file_picker 选择文件夹
