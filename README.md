# AI PDF Trans Mobile
本项目由 AI 辅助编程。

AI PDF Trans 的移动端客户端（APK）。通过本地 WiFi 连接到桌面端服务器，投递 PDF 翻译任务并实时查看进度。

注意：AI翻译排版等不可控，有可能会出现多次翻译效果不同的情况。并且手机远程翻译效果较电脑端直接使用较差。

PC端项目地址：https://github.com/Hjdd14/AI_PDF_Trans
## 系统要求

- **Flutter SDK** >= 3.4.0
- **Android Studio** (用于 Android SDK 和构建)
- **Android 8.0+** 设备

## 项目初始化

首次使用需要先运行 `flutter create` 生成 Android/iOS 平台脚手架：

```bash
cd ai_pdf_trans_apk

# 安装 Flutter 依赖
flutter pub get

# 生成平台文件（如果还没有 android/ 目录的完整结构）
flutter create --org com.hjdd14 --project-name ai_pdf_trans_apk .
```

## 运行（开发调试）

```bash
# 连接 Android 手机（USB 调试模式），然后：
flutter run
```

## 构建 APK

```bash
flutter build apk --release
# 输出: build/app/outputs/flutter-apk/app-release.apk
```

## 使用流程

1. 在桌面端启动 AI PDF Trans，进入 Settings → Remote Access，开启服务器
2. **局域网连接**：确保手机和电脑连接到同一个 WiFi，扫描桌面端显示的二维码
3. **跨网络连接**：两台设备安装 Tailscale 并登录同账号，扫描 Tailscale IP 的二维码
4. 连接成功后，选择手机上的 PDF 文件，设置语言，开始翻译
5. 实时查看进度，完成后下载并打开翻译好的 PDF

## 网络要求

### 局域网连接

- 手机和电脑必须在同一局域网（同一 WiFi / 同一路由器）
- 桌面端防火墙需要放行端口 8654（桌面端设置页面有检测提示）
- 部分公共 WiFi 启用了客户端隔离，可能无法连接——建议使用家庭/个人 WiFi

### 跨网络连接（Tailscale — 推荐）

当手机和电脑不在同一 WiFi 时（如电脑在家、手机在户外用 4G），通过 Tailscale 实现安全直连。

**设置步骤：**

1. 电脑端安装 Tailscale：访问 [tailscale.com/download](https://tailscale.com/download) 下载安装，登录 Google/GitHub/Microsoft 账号
2. 手机端安装 Tailscale：Google Play 搜索 "Tailscale" 安装，登录**同一个账号**
3. 确认连接：电脑端运行 `ipconfig` 查看 Tailscale 适配器的 `100.x.x.x` IP
4. 在桌面端 AI PDF Trans 设置页面开启远程服务器，软件会自动显示 Tailscale IP 和二维码
5. 手机 APP 扫码或手动输入 `http://100.x.x.x:8654` 即可连接

> Tailscale 免费版支持最多 100 台设备，完全满足个人使用。也支持 ZeroTier（Android 搜索 "ZeroTier One"）。

## 项目结构

```
lib/
├── main.dart
├── models/
│   ├── server_info.dart       # 服务器连接信息
│   └── task.dart              # 翻译任务状态
├── services/
│   ├── api_service.dart       # HTTP + WebSocket 客户端
│   └── storage_service.dart   # 本地存储（保存服务器地址）
└── screens/
    ├── connect_screen.dart    # 扫码连接 / 手动输入 IP
    ├── translate_screen.dart  # 选文件 + 语言设置 + 上传
    ├── progress_screen.dart   # WebSocket 实时进度
    └── result_screen.dart     # 下载 + 打开 PDF
```
