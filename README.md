# Eureka · 尤里卡

> 让知识真正掌握在你脑中 —— AI 驱动的学习强化训练系统

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter)](https://flutter.dev)
[![version](https://img.shields.io/badge/version-v1.2.0-5b4bd5)](https://github.com/congxin070708/eureka/releases)

Eureka（尤里卡）是一款基于 **掌握度门控 + 遗忘曲线复习** 的 AI 学习强化训练应用。
不只是"学过"，而是真正"学会"。

名字源自阿基米德的 *"Eureka!"*（我发现了！）—— 知识顿悟的那一刻。

---

## ✨ 核心特性

| 特性 | 说明 |
|------|------|
| 🧠 **掌握度门控** | 每个知识点独立评分，未达标不解锁新内容，防止蒙对一次就过关 |
| 🔄 **遗忘曲线复习** | 基于 SM-2 间隔重复算法，智能调度复习时间，记忆临界点及时巩固 |
| 🤖 **AI 智能出题** | 根据学习进度和薄弱点，动态生成个性化题目，针对性强化训练 |
| 🎯 **三种学习模式** | 速学（记忆型）/ 深度（概念型）/ 挑战（程序型），对应不同教学方式 |
| ⭐ **价值系数分级** | 神级 / 优质 / 中等 / 基础 / 拓展 五档标注重要程度 |
| 📊 **学习数据追踪** | 学习时长、答题数、正确率、连续天数，清晰看到进步轨迹 |
| 🔔 **复习提醒推送** | 本地通知定时提醒，每天准时复习 |
| 📌 **收藏与笔记** | 一键收藏重要知识点，打造自己的知识宝库 |
| 🔒 **数据安全** | API Key 加密存储（Keychain/Keystore），学习数据本地保存 |
| 💾 **数据导出/导入** | JSON 格式备份，支持跨设备迁移 |
| 🌙 **深色模式** | 支持明暗主题切换，护眼更舒适 |
| 🎮 **游戏化** | 等级 / XP / 连续签到 / 徽章 / 书架 |

---

## 📱 支持平台

| 平台 | 状态 | 说明 |
|------|------|------|
| Android | ✅ 完整支持 | APK 安装包 |
| iOS | ⚙️ 代码兼容 | 需自行签名构建 |
| **Web** | ✅ **两种方式** | [Flutter Web 完整 App](#方式一flutter-web-完整-app) + [纯 HTML 演示站](#方式二纯-html-演示站) |
| macOS / Windows / Linux | ⚙️ 代码兼容 | Flutter 桌面端可编译 |

---

## 🚀 快速开始

### 方式一：下载安装

前往 [Releases](https://github.com/congxin070708/eureka/releases) 下载最新版本安装包。

### 方式二：本地构建

```bash
# 克隆项目
git clone https://github.com/congxin070708/eureka.git
cd eureka

# 安装依赖
flutter pub get

# 运行（调试模式）
flutter run

# 构建 Android 安装包
flutter build apk --release

# 构建 Web 版
flutter build web --release
```

### 方式三：在线体验

- **产品官网（演示站）**：<https://congxin070708.github.io/eureka/>
- **Flutter Web 版**：自行构建后部署

---

## 🌐 Web 版（两种部署方式）

### 方式一：Flutter Web 完整 App

同一套 Flutter 代码编译为 Web，功能与移动端完全一致。

```bash
# 构建（CanvasKit 渲染，推荐桌面端）
flutter build web --release --web-renderer canvaskit

# 构建（HTML 渲染，推荐移动端）
flutter build web --release --web-renderer html
```

构建产物在 `build/web/` 目录，可部署到任意静态托管（GitHub Pages / Vercel / Netlify / Nginx）。

### 方式二：纯 HTML 演示站

位于 `docs/` 目录，独立的营销展示页面，零依赖、加载极快。

- 直接打开 `docs/index.html` 即可预览
- 功能介绍 + 在线演示面板 + 深色主题
- 可直接部署到 GitHub Pages（Settings → Pages → Source: master/docs）

详细说明见 [docs/README.md](docs/README.md)。

---

## ⚙️ 配置

在 App 的 **设置** 中填入你的 API Key 即可使用。支持多家兼容 OpenAI 协议的后端：

| 后端 | API 地址 | 推荐模型 |
|------|----------|----------|
| **DeepSeek** | `https://api.deepseek.com` | `deepseek-v4-flash` |
| **阿里云百炼** | `https://dashscope.aliyuncs.com/compatible-mode/v1` | `qwen-turbo` |
| **SiliconFlow** | `https://api.siliconflow.cn/v1` | `Qwen/Qwen2.5-7B-Instruct` |
| **OpenAI** | `https://api.openai.com/v1` | `gpt-4o-mini` |
| 其他兼容 OpenAI 协议的服务 | 自定义地址 | - |

> 🔐 API Key 使用 `flutter_secure_storage` 加密存储在本地，不会上传到任何服务器。

---

## 🧱 技术栈

- **框架**: Flutter 3.x (Dart 3.x)
- **状态管理**: Riverpod (ChangeNotifierProvider)
- **本地存储**:
  - `path_provider` + JSON 文件（学习数据）
  - `flutter_secure_storage`（API Key 加密存储）
  - `shared_preferences`（轻量配置）
- **AI 后端**: OpenAI 兼容 API
- **通知**: `flutter_local_notifications`
- **语音输入**: `speech_to_text`
- **数据导出**: `share_plus` + `file_picker`

### 项目结构

```
lib/
├── main.dart                     # 应用入口 + Riverpod 初始化
├── app_theme.dart                # 主题配色
├── version.dart                  # 版本号
├── study_engine.dart             # 核心学习引擎 (XP/等级/掌握度)
├── api_service.dart              # AI API 服务 (重试+缓存)
├── review_scheduler.dart         # 遗忘曲线复习调度器 (SM-2)
├── secure_storage_service.dart   # 加密存储服务
├── notification_service.dart     # 本地通知服务
├── file_storage_service.dart     # 文件持久化服务
├── data_export_service.dart      # 数据导出/导入服务
├── providers/
│   └── app_providers.dart        # Riverpod providers
├── screens/
│   ├── home_screen.dart          # 首页（书架+状态）
│   ├── learn_screen.dart         # 学习页（AI对话+答题）
│   ├── stats_screen.dart         # 统计中心
│   └── report_screen.dart        # 学习报告
├── widgets/
│   ├── chat_bubble.dart          # 消息气泡组件
│   ├── learn_input_bar.dart      # 输入栏组件
│   └── demo_panel.dart           # 演示面板组件
└── utils/
    └── input_validation.dart     # 输入验证工具
```

---

## 🧪 测试

```bash
# 运行全部单元测试
flutter test

# 运行指定测试
flutter test test/study_engine_test.dart
flutter test test/input_validation_test.dart
```

测试覆盖：
- 掌握度计算逻辑
- 序列化/反序列化
- 复习调度算法
- 输入验证（学科名、追问识别、无关输入拦截等）

---

## 📄 开源协议

[MIT License](LICENSE) - 可自由使用、修改、分发，保留版权声明即可。

---

## 🤝 致谢

学习机制设计参考：
- SM-2 间隔重复算法（SuperMemo）
- 掌握度学习理论（Bloom's Mastery Learning）

---

## 📮 反馈

有问题或建议欢迎提交 [Issue](https://github.com/congxin070708/eureka/issues)。

⭐ 如果你觉得这个项目有用，欢迎点个 Star 支持一下！
