# zed-simy

**English** | [简体中文](README.zh-CN.md)

> [Zed](https://zed.dev) editor support for **Simy**, a DSL for Minecraft datapack development.

This extension is **grammar-only**: it ships the Simy Tree-sitter grammar together with
highlighting and editor integration queries. No language server yet.

## Features

| Feature | Query |
| :--- | :--- |
| Syntax highlighting | [`highlights.scm`](languages/Simy/highlights.scm) |
| Bracket matching | [`brackets.scm`](languages/Simy/brackets.scm) |
| Auto-indentation | [`indents.scm`](languages/Simy/indents.scm) |
| Code folding | [`folds.scm`](languages/Simy/folds.scm) |
| Document outline | [`outline.scm`](languages/Simy/outline.scm) |
| Local scopes | [`locals.scm`](languages/Simy/locals.scm) |

Simy keywords, Minecraft atoms (selectors, coordinates, namespaced IDs, block states, raw
NBT), string interpolation and `$` references are all highlighted.

## Installation

Once published to the Zed extension registry:

1. Open the command palette (`zed: extensions`).
2. Search for **Simy** and install it.

### Installing as a development extension

1. Clone the repositories side by side (see [Requirements](#requirements)).
2. In Zed, run `zed: install dev extension` and select this directory.

Zed will build the extension and compile the grammar referenced in `extension.toml`.

## Requirements

- [Zed](https://zed.dev).
- Rust toolchain with the `wasm32-wasip1` target (only for dev installs):

  ```sh
  rustup target add wasm32-wasip1
  ```

## How it is wired

```toml
# extension.toml
[grammars.simy]
repository = "https://github.com/Neutriny/tree-sitter-simy"
rev = "bcc6d90a54f83b727d8f60aa5158e4192a642e59"
```

The language is declared in [`languages/Simy/config.toml`](languages/Simy/config.toml)
with `path_suffixes = ["simy"]`, so files ending in `.simy` use this language.

> The grammar lives in its own repository so that editors other than Zed can consume it.
> When you change query or config files, **rebuild the dev extension** — Zed reads them at
> install time.

## Related projects

| Repository | Role |
| :--- | :--- |
| **[simy](https://github.com/Neutriny/simy)** | Compiler and CLI |
| **[tree-sitter-simy](https://github.com/Neutriny/tree-sitter-simy)** | Tree-sitter grammar |
| **[docs/syntax.md](docs/syntax.md)** | Language reference |

## Publishing

Releases are automated: bump `version` in `extension.toml`, then push a tag (`v*`).
See [`.github/workflows/release.yml`](.github/workflows/release.yml).

## License

MIT
