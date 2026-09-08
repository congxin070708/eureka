# Eureka 三端打包发布指南

> Flutter 一套代码，iOS / Android / Web 三端发布

## 前置条件

```bash
flutter --version   # 需要 Flutter 3.x+
dart --version
```

- **iOS 打包**：需要 macOS + Xcode 15+
- **Android 打包**：需要 Android SDK + Java 17+
- **Web 打包**：任何平台都可以

---

## 一、Android 打包

### 1. 生成签名密钥

```bash
# macOS/Linux
keytool -genkey -v -keystore ~/eureka-keystore.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias eureka -storepass your_password -keypass your_password \
  -dname "CN=Eureka, OU=Dev, O=Eureka, L=Beijing, ST=Beijing, C=CN"

# Windows
keytool -genkey -v -keystore %USERPROFILE%\eureka-keystore.jks ^
  -keyalg RSA -keysize 2048 -validity 10000 -alias eureka
```

### 2. 配置签名

创建 `android/key.properties`：

```properties
storePassword=your_password
keyPassword=your_password
keyAlias=eureka
storeFile=/Users/yourname/eureka-keystore.jks
```

> ⚠️ `key.properties` 不要提交到 Git（已在 .gitignore 中）

### 3. 构建 APK

```bash
# 构建 release APK（通用包，所有架构）
flutter build apk --release

# 按架构拆分（推荐上架，体积更小）
flutter build apk --split-per-abi
# 产物：
#   build/app/outputs/flutter-apk/app-armeabi-v7a-release.apk  (32位ARM)
#   build/app/outputs/flutter-apk/app-arm64-v8a-release.apk    (64位ARM，主流)
#   build/app/outputs/flutter-apk/app-x86_64-release.apk       (x86_64模拟器)
```

### 4. 构建 App Bundle（Google Play 上架用）

```bash
flutter build appbundle --release
# 产物：build/app/outputs/bundle/release/app-release.aab
```

### 5. 版本号修改

在 `pubspec.yaml` 中修改：

```yaml
version: 2.0.0+1
#        ↑     ↑
#     版本名  版本号（每次上架+1）
```

---

## 二、iOS 打包

### 1. 配置 Apple 开发者账号

1. 登录 [Apple Developer](https://developer.apple.com/account/)
2. 创建 App ID：`com.eureka.ai`
3. 创建发布证书和 Provisioning Profile

### 2. 打开 Xcode 配置

```bash
open ios/Runner.xcworkspace
```

在 Xcode 中配置：

- **General** → Bundle Identifier: `com.eureka.ai`
- **General** → Version & Build: 从 pubspec 同步
- **Signing & Capabilities** → 选择 Team
- **Info** → 确认权限描述（已配置好）

### 3. 构建 Archive

```bash
# 先构建 release
flutter build ipa --release

# 或者在 Xcode 中：
# Product → Archive → Distribute App
```

产物在 `build/ios/ipa/` 目录。

### 4. 上架 TestFlight / App Store

1. Xcode → Window → Organizer → 选择 Archive → Distribute
2. 上传到 App Store Connect
3. 在 App Store Connect 填写应用信息
4. 提交审核

---

## 三、Web 打包

### 1. 构建

```bash
flutter build web --release
```

产物在 `build/web/` 目录。

### 2. 部署到 GitHub Pages

```bash
# 构建
flutter build web --release

# 推送到 gh-pages 分支（使用 peatmoss 工具或手动）
# 或直接把 build/web 内容推到 gh-pages 分支
```

### 3. 部署到任意静态服务器

将 `build/web/` 目录上传到任何静态托管服务：

- Vercel / Netlify
- Cloudflare Pages
- Nginx / Apache
- 阿里云 OSS / 腾讯云 COS

### 4. PWA 支持

Web 端已配置 PWA，用户可以「添加到主屏幕」像原生 App 一样使用。

---

## 四、三端功能对比

| 功能 | iOS | Android | Web |
|------|-----|---------|-----|
| AI 对话 | ✅ | ✅ | ✅ |
| 技能树 | ✅ | ✅ | ✅ |
| Boss 战 | ✅ | ✅ | ✅ |
| 抽奖系统 | ✅ | ✅ | ✅ |
| 文件学习 | ✅ | ✅ | ✅ |
| TTS 语音朗读 | ✅ | ✅ | ✅ |
| 语音识别输入 | ✅ | ✅ | ⚠️ 部分浏览器 |
| 本地通知 | ✅ | ✅ | ⚠️ 需 HTTPS |
| 离线使用 | ✅ | ✅ | ⚠️ PWA 缓存 |
| 安全存储 | ✅ | ✅ | ⚠️ localStorage |

---

## 五、常见问题

### Android: 安装失败
```bash
# 卸载旧版本
adb uninstall com.eureka.ai
```

### iOS: 真机调试
1. Xcode → Signing & Capabilities → 选择 Team
2. 手机设置 → 通用 → VPN与设备管理 → 信任开发者

### Web: API 跨域问题
部署到 HTTPS 域名后，如果 API 服务器没有 CORS 头，会报错。
解决：在 API 服务器添加 CORS 配置，或使用反向代理。

### 体积优化
```bash
# 分析包体积
flutter build apk --analyze-size

# Web 体积优化
flutter build web --release --web-renderer canvaskit
# 或使用 html 渲染器（体积更小）
flutter build web --release --web-renderer html
```
