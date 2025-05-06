# 📄 markdown-preview.nvim

A minimal Neovim plugin to preview Markdown files in a terminal split using [`glow`](https://github.com/charmbracelet/glow). Designed for speed, simplicity, and seamless Lazy.nvim integration.

---

## ✨ Features

- 🖥️ Previews the current buffer using `glow` in a horizontal terminal split
- 🧠 Smart use of tempfiles — no file saving needed
- 🔁 Lazy-loaded only when needed (`:MarkdownPreview`)

---

## 🚀 Requirements

- [Neovim 0.9+](https://neovim.io/)
- [glow](https://github.com/charmbracelet/glow) installed and available in your `$PATH`

---

## Installation

Install using the nvim as

```lua
{
    "Isaac7777-cpu/markdown-preview.nvim",
    cmd = "MarkdownPreview",
    config = function()
        require("markdown_preview")
    end,
}
```
