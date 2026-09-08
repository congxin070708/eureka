# Eureka 三端打包发布指南

> Flutter 一套代码，iOS / Android / Web 三端发布

## 快速发布（推荐）

项目已配置 GitHub Actions 自动构建，打 tag 即可自动发布双端包。

### 发布步骤

```bash
# 1. 修改 pubspec.yaml 版本号
# version: 2.0.0+1

# 2. 提交并打 tag
git add -A
git commit -m "release: v2.0.0"
git tag v2.0.0
git push origin v2.0.0
```

### 自动产出

打 tag 后，GitHub Actions 会自动运行并产出：

| 平台 | 产物 | 说明 |
|------|------|------|
| 🤖 Android | `eureka-2.0.0-arm64-v8a.apk` | 64 位 ARM，主流手机 |
| 🤖 Android | `eureka-2.0.0-armeabi-v7a.apk` | 32 位 ARM，老旧设备 |
| 🤖 Android | `eureka-2.0.0-x86_64.apk` | x86_64 模拟器 |
| 🤖 Android | `eureka-2.0.0.aab` | App Bundle，Google Play 上架 |
| 🍎 iOS | Runner.app（未签名） | 需要本地签名后分发 |
| 🌐 Web | `eureka-web-2.0.0.zip` | 静态站部署包 |

### 手动触发

也可以在 GitHub Actions 页面手动触发 Build Release 工作流，指定版本号。

---

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

---

## 六、CI/CD 工作流说明

### 工作流文件

- `.github/workflows/build-release.yml` — 发布构建（打 tag 触发）
- `.github/workflows/pr-check.yml` — PR 检查（analyze + test + build）

### 发布流程

```
打 tag v2.0.0
    ↓
触发 build-release workflow
    ├─ Android 构建 (Ubuntu)
    │   ├─ APK (3 种架构)
    │   └─ App Bundle
    ├─ iOS 构建 (macOS) ← 无签名，验证编译
    └─ Web 构建 (Ubuntu)
            ↓
      创建 Draft Release
     （自动上传所有产物）
            ↓
      手动确认后发布
```

### iOS 签名说明

> ⚠️ GitHub Actions 的 iOS 构建**不包含代码签名**，只验证编译是否通过。
> 原因：Apple 开发者证书属于敏感信息，且需要手动管理 Provisioning Profile。

**签名并发布 iOS 的两种方式：**

1. **本地 Xcode 签名（推荐）**
   ```bash
   flutter build ipa --release
   # 自动打开 Xcode，选择签名后导出
   ```

2. **CI 自动签名（高级）**
   - 将 p12 证书和 Provisioning Profile 存入 GitHub Secrets
   - 使用 `apple-actions/import-codesign-certs`  action
   - 需要维护证书和描述文件的更新

### 关于 Android 签名

CI 中的 Android 构建使用 debug 签名，只能用于测试。
**正式发布**需要：
1. 配置 `android/key.properties`（本地）
2. 或在 CI 中通过 Secrets 注入签名信息
3. 然后运行 `flutter build apk --release`
