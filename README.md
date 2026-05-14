# 墨阅 (MarkdownViewer)

> **墨色生香，阅见不凡。**
> 
> 一款为 macOS 精心打造的轻量级原生 Markdown 编辑与实时预览器。

![App Icon](AppIcon.png)

## ✨ 特性

- **极速体验**：基于 SwiftUI 原生开发，启动即用，丝滑滚动。
- **双栏预览**：左侧实时编辑，右侧高清渲染，支持 150ms 智能防抖解析。
- **高性能内核**：采用零依赖的 Foundation AttributedString 渲染技术，即便万字长文也能流畅处理。
- **原生美学**：完美适配 macOS 玻璃拟态设计与深色模式，提供沉浸式阅读体验。
- **文件树管理**：支持侧边栏目录浏览，轻松切换多个 Markdown 文档。
- **安全沙盒**：遵循 macOS 严格的沙箱机制，仅访问你授权的文件。

## 🚀 安装

1. 前往 [Releases](https://github.com/your-username/MarkdownViewer/releases) 下载最新的 `MarkdownViewer.app.zip`。
2. 解压后将 `MarkdownViewer.app` 拖入 **应用程序 (Applications)** 文件夹。
3. 首次运行时，若提示“开发者未验证”，请在“系统设置 -> 隐私与安全性”中点击“仍然打开”。

## ⌨️ 快捷键

- `⌘ + Shift + P`：循环切换视图模式（仅编辑、双栏、仅预览）
- `⌘ + B`：粗体
- `⌘ + I`：斜体
- `⌘ + K`：插入链接
- `⌘ + S`：保存文档

## 🛠 开发

本项目使用 Swift 6.2 编写，零外部依赖。

```bash
# 克隆仓库
git clone https://github.com/your-username/MarkdownViewer.git

# 编译运行
cd MarkdownViewer
swift run MarkdownViewer
```

## 📄 许可证

本项目基于 [MIT 协议](LICENSE) 开源。
