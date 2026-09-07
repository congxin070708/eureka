# 尤里卡 Web 版 - 两种部署方式

## 方式一：Flutter Web（完整 App 版）

同一套 Flutter 代码编译为 Web，功能与移动端完全一致。

### 本地运行

```bash
# 安装依赖
flutter pub get

# 运行 Web 版（调试模式）
flutter run -d chrome

# 构建生产版本
flutter build web --release
```

### CanvasKit vs HTML 渲染器

| 渲染器 | 特点 | 适用场景 |
|--------|------|----------|
| **CanvasKit** | 像素级一致、性能好、体积较大(~2MB) | 桌面端 / 追求视觉一致性 |
| **HTML** | 体积小、加载快、渲染略逊 | 移动端 / 追求加载速度 |

```bash
# CanvasKit 渲染（默认，推荐桌面端）
flutter build web --web-renderer canvaskit

# HTML 渲染（推荐移动端）
flutter build web --web-renderer html

# 自动选择（canvaskit for desktop, html for mobile）
flutter build web --web-renderer auto
```

### 部署

构建产物在 `build/web/` 目录，可部署到任意静态托管：

- **GitHub Pages**: 推送 `build/web` 到 `gh-pages` 分支
- **Vercel / Netlify**: 直接拖拽 `build/web` 文件夹
- **Nginx**: 放到静态资源目录即可

---

## 方式二：纯 HTML 演示站（Landing Page）

位于 `docs/` 目录，独立的营销展示页面，零依赖、加载快。

### 特点

- 纯 HTML/CSS/JS，零依赖
- 深色 / 浅色主题切换
- 响应式设计，适配移动端
- 产品功能介绍 + 在线演示面板
- 可直接部署到 GitHub Pages

### 本地预览

```bash
# 方式1：直接打开
open docs/index.html

# 方式2：用 Python 起本地服务
cd docs && python3 -m http.server 8080
```

### GitHub Pages 部署

1. 进入仓库 Settings → Pages
2. Source 选择 `Deploy from a branch`
3. Branch 选择 `master`，目录选择 `/docs`
4. 保存后访问 `https://<username>.github.io/eureka/`

---

## 两种方式对比

| 维度 | Flutter Web 版 | HTML 演示站 |
|------|---------------|-------------|
| **功能** | 完整 App 功能 | 产品介绍 + 演示 |
| **加载速度** | 较慢（需加载 Dart SDK） | 极快（纯静态） |
| **SEO** | 一般 | 好 |
| **维护成本** | 低（一套代码） | 中（独立维护） |
| **适用场景** | 实际使用产品 | 营销 / 展示 / 引流 |

### 推荐组合

- **docs/index.html** → 作为 Landing Page（GitHub Pages 部署）
- **Flutter Web** → 作为实际使用的 Web App（部署到子路径或独立域名）
