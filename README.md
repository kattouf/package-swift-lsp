# Package.swift LSP

![](https://img.shields.io/badge/Platforms-macOS%20|%20Linux-6464aa)
[![Latest Release](https://img.shields.io/github/release/kattouf/package-swift-lsp.svg)](https://github.com/kattouf/package-swift-lsp/releases/latest)
[![codecov](https://codecov.io/gh/kattouf/package-swift-lsp/graph/badge.svg?token=ZV3UW5KJ6U)](https://codecov.io/gh/kattouf/package-swift-lsp)
![Build Status](https://github.com/kattouf/package-swift-lsp/actions/workflows/checks.yml/badge.svg?branch=main)

A Language Server Protocol (LSP) implementation for Swift Package Manager's Package.swift manifest files.

![demo](https://github.com/user-attachments/assets/4caa7126-a2d7-45dd-b663-2d3f31817f74)

## Overview

Language server for Package.swift files that provides:

- Smart code completion for Package.swift manifest files:
  - In `.package(...)` function:
    - `url:` argument with GitHub repository suggestions
    - `from:` and `exact:` arguments with version suggestions
    - `branch:` argument with available branch names
  - In `.product(...)` function:
    - `name:` argument with available product suggestions from dependencies
    - `package:` argument with package name suggestions
  - In `.target(...)` function:
    - `name:` argument with local target name suggestions from your package
  - In target dependencies string literals:
    - Product name completion that automatically expands to `.product(name: "ProductName", package: "PackageName")` format
    - Local target name completion for referencing targets within your package to `.target(name: "LocalTarget")` format
> [!NOTE]
> After editing package dependencies (`.package(...)`), save the file for changes to be reflected in target completions.

- Contextual hover information:
  - Package details including location and state when hovering over package names
  - Available products in the package

## Installation & Editor Integration

The easiest way to get started is through editor extensions:

- **[Zed](https://zed.dev/)**: Install the [Package.swift LSP extension](https://github.com/kattouf/package-swift-lsp-zed) from the Zed extension marketplace
- **[Visual Studio Code](https://code.visualstudio.com/)**: Install the [Package.swift LSP extension](https://github.com/kattouf/package-swift-lsp-vscode) from the VSCode marketplace
- **[Neovim](https://neovim.io/)**: Install the [Package.swift LSP plugin](https://github.com/kattouf/package-swift-lsp-neovim) using your preferred plugin manager

Support for additional editors is planned. If you'd like to see support for your preferred editor, please submit a feature request or consider contributing!

The LSP server binary can also be downloaded directly from the [GitHub releases page](https://github.com/kattouf/package-swift-lsp/releases/latest).

## Acknowledgements

Thanks to the people and projects that helped make this LSP possible:

- [@mattmassicotte](https://github.com/mattmassicotte) for [ChimeHQ/LanguageServerProtocol](https://github.com/ChimeHQ/LanguageServerProtocol) - a solid foundation for this project
- [Swift Package Index](https://swiftpackageindex.com/) - for providing great package data for our URL completions

## Contributing

- Feel free to submit feature requests if you have ideas for improving Package.swift editing experience
- For substantial contributions (beyond small fixes), please open a discussion first to align on direction and implementation approach

## License

Server is available under the MIT license. See the [LICENSE](LICENSE) file for more info.
