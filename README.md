# Package.swift LSP

![](https://img.shields.io/badge/Platform-macOS-6464aa)
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

  > **Note:** After editing package dependencies (`.package(...)`), save the file for changes to be reflected in target completions.
- Contextual hover information:
  - Package details including location and state when hovering over package names
  - Available products in the package

## Installation

Installation instructions are currently in progress. Stay tuned for detailed setup guides.

## Editor Integration

Editor integration guides for popular IDEs and text editors are currently being developed. Support for various editors (Zed, VSCode, Vim, Emacs, etc.) will be available soon.

## Acknowledgements

Thanks to the people and projects that helped make this LSP possible:

- [@mattmassicotte](https://github.com/mattmassicotte) for [ChimeHQ/LanguageServerProtocol](https://github.com/ChimeHQ/LanguageServerProtocol) - a solid foundation for this project
- [Swift Package Index](https://swiftpackageindex.com/) - for providing great package data for our URL completions

## Contributing

- Feel free to submit feature requests if you have ideas for improving Package.swift editing experience
- For substantial contributions (beyond small fixes), please open a discussion first to align on direction and implementation approach

## License

Server is available under the MIT license. See the [LICENSE](LICENSE) file for more info.
