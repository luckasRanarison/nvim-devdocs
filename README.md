# nvim-devdocs

nvim-devdocs is a plugin which brings [DevDocs](https://devdocs.io) documentations into neovim. Install, search and preview documentations directly inside neovim in markdown format with telescope integration.

## Preview

![nvim-devdocs search](./.github/preview.png)

## Installation

Lazy:

```lua
return {
  "luckasRanarison/nvim-devdocs",
  dependencies = {
    "nvim-lua/plenary.nvim",
    "nvim-telescope/telescope.nvim",
    "nvim-treesitter/nvim-treesitter",
  },
  opts = {}
}
```

Packer:

```lua
use {
  "luckasRanarison/nvim-devdocs",
  requires = {
    "nvim-lua/plenary.nvim",
    "nvim-telescope/telescope.nvim",
    "nvim-treesitter/nvim-treesitter",
  },
  config = function()
    require("nvim-devdocs").setup()
  end
}
```

The plugin uses treesitter API for converting HTML to markdown so make sure you have treesitter `html` parser installed.

Inside your treesitter configuration:

```lua
{
  ensure_installed = { "html" },
}
```

## Configuration

Here is the default configuration:

```lua
{
  dir_path = vim.fn.stdpath("data") .. "/devdocs", -- installation directory
  telescope = {}, -- passed to the telescope picker
  telescope_alt = { -- when searching globally without preview
    layout_config = {
      width = 75,
    },
  },
  float_win = { -- passed to nvim_open_win(), see :h api-floatwin
    relative = "editor",
    height = 25,
    width = 100,
    border = "rounded",
  },
  wrap = false, -- text wrap
  ensure_installed = {}, -- get automatically installed
}
```

## Commands

Available commands:

- `DevdocsFetch`: Fetch DevDocs metadata.
- `DevdocsInstall`: Install documentation, 0-n args.
- `DevdocsUninstall`: Uninstall documentation, 0-n args.
- `DevdocsOpen`: Open documentation in a normal buffer, 0 or 1 arg.
- `DevdocsOpenFloat`: Open documentation in a floating window, 0 or 1 arg.
- `DevdocsUpdate`: Update documentation, 1-n args.
- `DevdocsUpdateAll`: Update all documentations.

Commands support completion.

> ℹ️ **NOTE**:<br>
> At the moment, Telescope's Previewer is available only when opening a specific documentation.
> E.g. `:DevdocsOpen javascript` 

## TODO

- More search options
- External previewers.
- More features.

## Contributing

The HTML converter is still experimental, and not all documentation has been thoroughly tested yet. If you encounter rendering issues, feel free to submit an [issue](https://github.com/luckasRanarison/nvim-devdocs/issues).

Pull requests and feature requests are welcome!

## Credits

- [The DevDocs project](https://github.com/freeCodeCamp/devdocs) for the documentations.
- [devdocs.el](https://github.com/astoff/devdocs.el) for inspiration.
