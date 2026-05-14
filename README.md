# 墨阅 (MarkdownViewer)

> **墨色生香，阅见不凡。**
>
> 一款为 macOS 15+ 打造的原生 Markdown 编辑与实时预览应用。Swift 6.2 + SwiftUI，SPM 管理，零第三方依赖。


## 特性

- **默认纯预览**：打开即读；按 `⌘E` 进入双栏编辑（`NSTextView` + `WKWebView`），可切换左右 / 上下分栏。
- **实时预览**：自研 Markdown → HTML 解析，预览在 `WKWebView` 中渲染；编辑侧防抖约 **80ms** 后全量重解析。
- **侧栏大纲**：`NavigationSplitView` 侧栏展示标题结构，点击可同步滚动预览中的对应位置。
- **样式**：支持同目录同名 `.css`、设置中的自定义 CSS，以及内置 `default.css`（浅色 / 深色跟随系统）。
- **沙盒**：使用用户授权与书签访问磁盘上的 Markdown 与相关资源。

## 系统要求

- macOS **15** 及以上
- Xcode / Swift 6.2 工具链（本地开发时）

## 安装（正式包）

1. 在 [Releases](https://github.com/chenxinxing/MarkdownViewer/releases) 下载最新的 `MarkdownViewer.app.zip`。
2. 解压后将 `MarkdownViewer.app` 拖入 **应用程序** 文件夹。
3. 若出现「无法验证开发者」，在 **系统设置 → 隐私与安全性** 中选择 **仍要打开**。

## 快捷键（与菜单一致）

| 快捷键 | 功能 |
|--------|------|
| `⌘O` | 打开文件 |
| `⌘S` | 保存 |
| `⌘⇧S` | 另存为 |
| `⌘E` | 切换编辑 / 预览模式 |
| `⌘\` | 编辑模式下切换分栏方向（横 / 竖） |
| `⌘B` / `⌘I` | 粗体 / 斜体 |
| `⌘K` | 插入链接 |

## 开发

Swift 包位于本目录（含 `Package.swift` 与 `Sources/`）。请在 **`MarkdownViewer` 目录下** 执行命令：

```bash
# 克隆仓库
git clone https://github.com/chenxinxing/MarkdownViewer.git
cd MarkdownViewer

# 调试编译并运行
swift build
swift run MarkdownViewer

# 可选：直接打开指定文件
swift run MarkdownViewer /path/to/file.md
```

Release 构建：

```bash
swift build -c release
```

### 打包为 .app

在本目录执行：

```bash
./package_app.sh
```

脚本会先执行 `swift package clean`，再以 **release** 模式编译（`-j 1` 以降低与编辑器同时写入源文件时的冲突概率），生成 `MarkdownViewer.app` 并完成签名。若仍出现「input file was modified during the build」，请在打包过程中暂时关闭对该目录的 **自动保存 / 保存时格式化**，并避免并行的另一场 `swift build`。

## 工程结构（摘要）

| 路径 | 说明 |
|------|------|
| `Sources/ViewModels/DocumentViewModel.swift` | 文档状态、解析调度、文件与 CSS 解析 |
| `Sources/Services/MarkdownParser.swift` | Markdown → HTML |
| `Sources/Views/Preview/PreviewView.swift` | 预览（WKWebView） |
| `Sources/Views/Editor/EditorView.swift` | 编辑器（NSTextView） |
| `Sources/Resources/` | 内置资源（如 `default.css`、本地化字符串） |
| `package_app.sh` | 打 release 包并 codesign |
| `Info.plist` / `MarkdownViewer.entitlements` | 包元数据与沙盒权限 |

## 许可证

以仓库根目录的 **LICENSE** 文件为准（若尚未添加，可自行补充后再更新本段链接）。
