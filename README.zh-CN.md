# zed-simy

[English](README.md) | **简体中文**

> 面向 **Simy**（Minecraft 数据包开发 DSL）的 [Zed](https://zed.dev) 编辑器支持。

本扩展是**纯语法扩展**：提供 Simy 的 Tree-sitter 语法以及高亮与编辑器集成查询，暂不含语言服务器。

## 功能

| 功能 | 查询文件 |
| :--- | :--- |
| 语法高亮 | [`highlights.scm`](languages/Simy/highlights.scm) |
| 括号匹配 | [`brackets.scm`](languages/Simy/brackets.scm) |
| 自动缩进 | [`indents.scm`](languages/Simy/indents.scm) |
| 代码折叠 | [`folds.scm`](languages/Simy/folds.scm) |
| 文档大纲 | [`outline.scm`](languages/Simy/outline.scm) |
| 局部作用域 | [`locals.scm`](languages/Simy/locals.scm) |

Simy 关键字、Minecraft 原子（选择器、坐标、命名空间 ID、方块状态、原始 NBT）、
字符串内插与 `$` 引用均有高亮。

## 安装

发布到 Zed 扩展市场后：

1. 打开命令面板（`zed: extensions`）。
2. 搜索 **Simy** 并安装。

### 作为开发扩展安装

1. 克隆各个仓库到相邻目录（见[环境要求](#环境要求)）。
2. 在 Zed 中运行 `zed: install dev extension`，选择本目录。

Zed 会构建扩展，并编译 `extension.toml` 中引用的语法。

## 环境要求

- [Zed](https://zed.dev)。
- 带 `wasm32-wasip1` target 的 Rust 工具链（仅开发安装需要）：

  ```sh
  rustup target add wasm32-wasip1
  ```

## 接线方式

```toml
# extension.toml
[grammars.simy]
repository = "https://github.com/Neutriny/tree-sitter-simy"
rev = "bcc6d90a54f83b727d8f60aa5158e4192a642e59"
```

语言在 [`languages/Simy/config.toml`](languages/Simy/config.toml) 中声明，
`path_suffixes = ["simy"]` 让 `.simy` 后缀的文件使用该语言。

> 语法独立成仓，便于 Zed 之外的编辑器复用。修改查询或配置文件后请**重建开发扩展**——
> Zed 只在安装时读取这些文件。

## 文档

语言参考位于 [`docs/`](docs/)：

| 文件 | 语言 |
| :--- | :--- |
| [`docs/syntax.md`](docs/syntax.md) | English |
| [`docs/syntax.zh-CN.md`](docs/syntax.zh-CN.md) | 简体中文 |

## 相关项目

| 仓库 | 作用 |
| :--- | :--- |
| **[simy](https://github.com/Neutriny/simy)** | 编译器与 CLI |
| **[tree-sitter-simy](https://github.com/Neutriny/tree-sitter-simy)** | Tree-sitter 语法 |

## 发布

发布已自动化：改 `extension.toml` 的 `version`，然后推送 `v*` tag。
详见 [`.github/workflows/release.yml`](.github/workflows/release.yml)。

## 许可证

MIT
