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

## 技术栈

- Flutter + Material 3
- flutter_bloc 状态管理
- shared_preferences 保存总目录路径
- file_picker 选择文件夹
