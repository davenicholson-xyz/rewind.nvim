# rewind.nvim

A Neovim plugin that provides a telescope interface for browsing and restoring file versions using the [Rewind](https://github.com/rewind-ai/rewind) CLI tool.

## Features

- **Browse file versions**: Use `:Rewind` to see all versions of the current file
- **Browse tagged versions**: Use `:RewindTag` to see only tagged versions of the current file
- **Telescope integration**: Familiar fuzzy-finding interface with file preview
- **One-click restore**: Select any version to instantly restore your file

## Prerequisites

- [Rewind CLI](https://github.com/rewind-ai/rewind) installed and configured
- [telescope.nvim](https://github.com/nvim-telescope/telescope.nvim) installed
- Must be inside a Rewind-tracked directory

## Installation

### Using [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  "your-username/rewind.nvim",
  dependencies = { "nvim-telescope/telescope.nvim" },
  config = function()
    require("rewind").setup()
  end,
}
```

### Using [packer.nvim](https://github.com/wbthomason/packer.nvim)

```lua
use {
  "your-username/rewind.nvim",
  requires = { "nvim-telescope/telescope.nvim" },
  config = function()
    require("rewind").setup()
  end,
}
```

## Usage

### Commands

- `:Rewind` - Browse all versions of the current file
- `:RewindTag` - Browse only tagged versions of the current file

### Keybindings

You can create custom keybindings for quick access:

```lua
vim.keymap.set("n", "<leader>rw", ":Rewind<CR>", { desc = "Browse file versions" })
vim.keymap.set("n", "<leader>rt", ":RewindTag<CR>", { desc = "Browse tagged versions" })
```

### Telescope Interface

- **Navigate**: Use `j`/`k` or arrow keys to browse versions
- **Preview**: File content is automatically previewed
- **Select**: Press `<Enter>` to restore the selected version
- **Cancel**: Press `<Esc>` or `<C-c>` to cancel

## How It Works

The plugin uses `rewind rollback <filename> -j` to fetch version history and presents it through telescope's picker interface. When you select a version, it runs `rewind rollback <filename> -v <version>` to restore the file.

## License

MIT
