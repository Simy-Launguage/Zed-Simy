use zed_extension_api as zed;

/// Simy language support for Zed.
///
/// This extension is grammar-only: it ships the `simy` Tree-sitter grammar
/// (declared in `extension.toml`) together with the query files under
/// `languages/Simy/`. No language server is provided yet.
struct SimyExtension;

impl zed::Extension for SimyExtension {
    fn new() -> Self {
        Self
    }
}

zed::register_extension!(SimyExtension);
