# 📄 markdown-preview.nvim

A minimal Neovim plugin to preview Markdown files in a terminal split using [`glow`](https://github.com/charmbracelet/glow). Designed for speed, simplicity, and seamless Lazy.nvim integration. The goals is for me to quickly view the documentation instead of used as a markdown previewer as one would use as if the vscode in-built markdown.

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
    name = "markdown-preview.nvim", -- Optional name used internally
    cond = function()
        if vim.fn.executable("glow") ~= 1 then
            vim.notify("[markdown-preview.nvim] Skipped: glow not found in PATH", vim.log.levels.WARN)
            return false
        end
        return true
    end,
    config = function()
        require("markdown_preview") -- loads lua/markdown_preview/init.lua

        vim.keymap.set("n", "kK", "<cmd>DocumentationPreview<CR>",
            { desc = "Full Documentation Preview with Glow to see a nice layout of documentation." })
    end
}
```

---

## Acknowledge

This repository has taken inspiration from [this great repository](https://github.com/ellisonleao/glow.nvim) which has unfortunately been archived by the owner recently.
