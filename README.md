# 🐾 Pawser

**Pawser** is a fast, fault-tolerant compiler frontend library for the Scatty programming language.

Designed with modern IDE tooling in mind, Pawser serves as the unified syntactic and semantic backbone for both the compiler's and the LSP's.

## Key Features

* **Unified Frontend Pipeline:** Provides a complete suite of frontend stages-including lexical analysis (Lexer), syntax tree generation (Parser), and semantic analysis (Analyzer).
* **Fault-Tolerant by Design:** Built with robust error recovery strategies. Pawser can handle incomplete, malformed, or mid-typing code to always produce a usable syntax tree.
* **LSP-Ready Architecture:** Tracks precise source locations (spans/ranges) and provides structured, non-fatal diagnostics tailored for real-time Language Server Protocol interactions.
* **First-Class Doc-Comments:** Natively parses and attaches documentation comments directly to syntax nodes, powering instant IDE hover tooltips and automated documentation generation.
* **Zero Redundancy:** By sharing the exact same frontend between the compiler and the language server, Scatty guarantees 100% consistency between IDE diagnostics and compilation results.

## Roadmap & Status

- [x] **Lexer:** Tokenization, literals, trivia, and doc-comment extraction
- [ ] **Parser:** Fault-tolerant AST/CST generation and error recovery
- [ ] **Analyzer:** Semantic analysis, symbol resolution, and type checking
- [ ] **LSP Bindings:** Direct helper APIs for Language Server capabilities

## License

This project is part of the Scatty language ecosystem. See the `LICENSE` file for more details.
