# Eureka · 尤里卡

> 让知识真正掌握在你脑中 —— AI 驱动的学习强化训练系统

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter)](https://flutter.dev)
[![version](https://img.shields.io/badge/version-v1.2.0-5b4bd5)](https://github.com/congxin070708/eureka/releases)
[![CI/CD](https://img.shields.io/badge/CI%2FCD-GitHub%20Actions-2088FF?logo=githubactions)](https://github.com/congxin070708/eureka/actions)

Eureka（尤里卡）是一款基于 **掌握度门控 + 遗忘曲线复习 + 游戏化激励** 的 AI 学习强化训练应用。
不只是"学过"，而是真正"学会"。

名字源自阿基米德的 *"Eureka!"*（我发现了！）—— 知识顿悟的那一刻。

---

## ✨ 核心特性

### 学习引擎

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

### 游戏化系统（模仿"学霸的黑科技系统"）

| 特性 | 说明 |
|------|------|
| ⭐ **技能树** | 网状知识图谱，节点状态机（锁定→可学→学习中→掌握→精通），前置依赖自动解锁 |
| 📋 **任务系统** | 日常任务（每日刷新）+ 主线任务（一次性），完成任务获取经验/道具/抽奖券 |
| 🎰 **抽奖系统** | 四档稀有度（普通/稀有/史诗/传说），**软保底 + 硬保底**机制防止非酋退坑 |
| 🎒 **道具背包** | 经验卡（双倍经验）、提示卡、跳过卡、解锁钥匙、称号等多类型道具 |
| 👹 **Boss 战** | 限时多阶段策略性答题，血条 + 连击倍率 + Boss 反击，应用题多解法加分 |
| 📖 **学科启动页** | 系统"扫描"基础 → 发布主线任务 + 推荐书单，像系统一样发布任务 |
| 🔊 **语音系统** | TTS 朗读 AI 消息 + 语音识别口述答题，解放双手 |
| 📄 **文件学习** | 上传代码/文档/论文，智能检测内容类型并分段，逐段 AI 讲解 + 出题 + 评分 |
| 📝 **论文两阶段学习** | 格式学习（论文结构）+ 内容学习（核心内容），分开考察理解深度 |

### 基础设施

| 特性 | 说明 |
|------|------|
| 🔒 **数据安全** | API Key 加密存储（Keychain/Keystore），学习数据本地持久化 |
| 💾 **数据导出/导入** | JSON 格式备份，支持跨设备迁移 |
| 🌙 **深色模式** | 支持明暗主题切换，护眼更舒适 |
| 🔌 **API 自动检测** | 按 Key 前缀识别后端（百炼/OpenAI/SiliconFlow/DeepSeek），探测模型列表，失败降级走缓存 |
| 🔤 **字体优化** | 使用 google_fonts 按需加载，APK 体积从 32MB 字体瘦身到几 MB |
| 🚀 **CI/CD** | GitHub Actions 自动构建三端（Android/iOS/Web）+ PR 检查（analyze + test + build） |

---

## 📱 支持平台

| 平台 | 状态 | 说明 |
|------|------|------|
| Android | ✅ 完整支持 | APK 安装包（split per ABI）+ App Bundle |
| iOS | ⚙️ 代码兼容 | CI 验证编译通过，需本地签名后分发 |
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

在 App 的 **设置** 中填入你的 API Key 即可使用。支持多家兼容 OpenAI 协议的后端，自动检测后端类型：

| 后端 | Key 前缀 | API 地址 | 推荐模型 |
|------|----------|----------|----------|
| **DeepSeek** | `sk-` | `https://api.deepseek.com` | `deepseek-v4-flash` |
| **阿里云百炼** | `sk-sp-` | `https://dashscope.aliyuncs.com/compatible-mode/v1` | `qwen-plus` |
| **OpenAI** | `sk-proj-` | `https://api.openai.com/v1` | `gpt-4o-mini` |
| **SiliconFlow** | `sk-sid-` | `https://api.siliconflow.cn/v1` | `deepseek-ai/DeepSeek-V3` |
| 其他兼容 OpenAI 协议的服务 | 自定义 | 自定义地址 | - |

> 🔐 API Key 使用 `flutter_secure_storage` 加密存储在本地，不会上传到任何服务器。

---

## 🧱 技术栈

- **框架**: Flutter 3.x (Dart 3.x)
- **状态管理**: Riverpod (NotifierProvider / ChangeNotifier)
- **本地存储**:
  - `path_provider` + JSON 文件（学习数据）
  - `flutter_secure_storage`（API Key 加密存储）
  - `shared_preferences`（轻量配置）
- **AI 后端**: OpenAI 兼容 API（DeepSeek V4 / 百炼 / OpenAI / SiliconFlow）
- **通知**: `flutter_local_notifications`
- **语音**: `flutter_tts`（TTS 朗读）+ `speech_to_text`（语音识别）
- **字体**: `google_fonts`（按需加载 Noto Sans SC，无需打包大字体文件）
- **数据导出**: `share_plus` + `file_picker`
- **CI/CD**: GitHub Actions（三端自动构建 + PR 检查）

### 项目结构

```
lib/
├── main.dart                     # 应用入口 + Riverpod 初始化 + TTS 初始化
├── app_theme.dart                # 主题配色
├── version.dart                  # 版本号
├── study_engine.dart             # 核心学习引擎 (XP/等级/掌握度/抽奖保底)
├── api_service.dart              # AI API 服务 (自动检测+重试+缓存)
├── prompts.dart                  # AI 教学提示词库
├── review_scheduler.dart         # 遗忘曲线复习调度器 (SM-2)
├── secure_storage_service.dart   # 加密存储服务
├── notification_service.dart     # 本地通知服务
├── file_storage_service.dart     # 文件持久化服务
├── data_export_service.dart      # 数据导出/导入服务
├── skill_tree.dart               # 技能树系统 (节点/依赖/状态机/预设)
├── task_system.dart              # 任务系统 + 抽奖系统(保底) + 道具背包
├── boss_battle.dart              # Boss 战系统 (血条/连击/限时/多阶段)
├── voice_service.dart            # 语音服务 (TTS 朗读 + 状态管理)
├── paper_learning_service.dart   # 论文学习服务 (格式+内容两阶段)
├── smart_content_detector.dart   # 智能内容检测器 (代码/论文/数学/文本)
├── file_learning_service.dart     # 文件学习服务 (分段+出题+评分)
├── providers/
│   └── app_providers.dart        # Riverpod providers
├── screens/
│   ├── home_screen.dart          # 首页（书架+状态面板+任务入口）
│   ├── learn_screen.dart         # 学习页（AI对话+答题+Boss模式）
│   ├── skill_tree_screen.dart    # 技能树可视化
│   ├── subject_launch_screen.dart # 学科启动页（任务发布+书单）
│   ├── file_learning_screen.dart  # 文件学习页
│   ├── gacha_screen.dart         # 抽奖+背包页
│   ├── stats_screen.dart         # 统计中心
│   └── report_screen.dart        # 学习报告
├── widgets/
│   ├── chat_bubble.dart          # 消息气泡（含语音朗读按钮）
│   ├── learn_input_bar.dart      # 输入栏组件
│   ├── demo_panel.dart           # 演示面板组件
│   ├── api_key_guide_sheet.dart  # API Key 引导面板
│   ├── onboarding_screen.dart    # 新用户引导页
│   └── level_up_overlay.dart     # 升级全屏特效
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

## 🚀 CI/CD

项目配置了 GitHub Actions 自动化工作流：

| 工作流 | 文件 | 触发条件 | 产出 |
|--------|------|----------|------|
| **Build Release** | `build-release.yml` | 打 `v*` tag | Android APK (3架构) + AAB + iOS (验证编译) + Web + GitHub Release |
| **PR Check** | `pr-check.yml` | PR / push to main | Flutter analyze + 单元测试 + Android/Web 构建检查 |

详细打包发布指南见 [DEPLOY.md](docs/DEPLOY.md)。

---

## 📄 开源协议

[MIT License](LICENSE) - 可自由使用、修改、分发，保留版权声明即可。

---

## 🤝 致谢

学习机制设计参考：
- SM-2 间隔重复算法（SuperMemo）
- 掌握度学习理论（Bloom's Mastery Learning）
- 游戏化设计参考"学霸的黑科技系统"

---

## 📮 反馈

有问题或建议欢迎提交 [Issue](https://github.com/congxin070708/eureka/issues)。

⭐ 如果你觉得这个项目有用，欢迎点个 Star 支持一下！
