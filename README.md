# nvim-config

My Neovim setup: [LazyVim](https://www.lazyvim.org/) with a Nord look, a few small custom modules, and tight integration with WezTerm and Claude Code.

This repo is a **snapshot**. The live config is managed with chezmoi; this copy is updated from it periodically.

## What's in it

```
init.lua                  bootstraps lazy.nvim (lua/config/lazy.lua)
lazyvim.json              LazyVim extras: editor.neo-tree, lang.dotnet
lazy-lock.json            pinned plugin versions
lua/config/
  options.lua             word wrap, PATH fix for winget CLIs, disabled providers
  keymaps.lua             Ctrl-h/j/k/l across Neovim windows and WezTerm panes,
                          Windows-style Ctrl-z/y/c/x/v, accelerating arrow keys
  autocmds.lua            wires up the modules below
  typewriter.lua          files changed on disk (e.g. by Claude) replay as typing, then flash
  claude_jump.lua         jumps the editor to the file Claude is about to edit
  recent_files.lua        "Recent files" panel pinned above the neo-tree
  start_screen.lua        closing the last editor window reopens the start screen
  terminal.lua            :terminal opens below the editor; :q closes it directly
  cmdline_center.lua      centres the noice ":" popup on the editor pane
lua/plugins/
  ui.lua                  nord.nvim (transparent), neo-tree Files|Git tabs, lualine, snappier scroll
  claudecode.lua          coder/claudecode.nvim with <leader>a* keys
  completion.lua          blink.cmp: Tab accepts
  noice.lua               cmdline popup position
  example.lua             LazyVim starter example (disabled)
extras/claude-code/
  nvim-jump.js            Claude Code hook used by claude_jump.lua
smart-splits.lua.disabled old smart-splits spec, kept for reference
```

## Install

Back up any existing config first, then clone.

**Windows**

```powershell
git clone https://github.com/dgrammatico/nvim-config "$env:LOCALAPPDATA\nvim"
nvim
```

**Linux / WSL**

```sh
git clone https://github.com/dgrammatico/nvim-config ~/.config/nvim
nvim
```

On WSL you can also symlink `~/.config/nvim` to the Windows copy so both share one config:

```sh
ln -s /mnt/c/Users/<you>/AppData/Local/nvim ~/.config/nvim
```

lazy.nvim installs every plugin on first launch.

## Requirements

- Neovim 0.10+ and git
- A Nerd Font (icons in neo-tree and lualine)
- ripgrep, fd, lazygit, fzf (on Windows, `options.lua` adds the winget links folder to PATH)
- Optional: [WezTerm](https://wezterm.org/) for pane navigation, [Claude Code](https://claude.com/claude-code) for the `<leader>a` keys

## Claude Code jump hook (optional)

`claude_jump.lua` writes Neovim's RPC pipe address to `stdpath("data")/claude-jump-server`. The hook in `extras/claude-code/nvim-jump.js` reads it and tells Neovim to open whichever file Claude is about to edit, so the typewriter animation plays in view.

1. Copy `nvim-jump.js` to `~/.claude/hooks/`.
2. Add this to `~/.claude/settings.json` (adjust the path):

```json
{
  "hooks": {
    "PreToolUse": [
      { "matcher": "Edit|Write|MultiEdit|NotebookEdit",
        "hooks": [{ "type": "command", "command": "node \"C:/Users/<you>/.claude/hooks/nvim-jump.js\"", "timeout": 5 }] }
    ],
    "PostToolUse": [
      { "matcher": "Edit|Write|MultiEdit|NotebookEdit",
        "hooks": [{ "type": "command", "command": "node \"C:/Users/<you>/.claude/hooks/nvim-jump.js\"", "timeout": 5 }] }
    ]
  }
}
```

The hook is Windows-oriented: it looks under `%LOCALAPPDATA%\nvim-data`. It exits silently if Neovim isn't running.

## Key bindings (beyond LazyVim defaults)

| Keys | Action |
|---|---|
| `Ctrl-h/j/k/l` | Move between windows; at the edge, move to the neighbouring WezTerm pane |
| `Alt-c` | Toggle/focus Claude |
| `<leader>ac` / `af` / `ar` / `aC` | Claude: toggle / focus / resume / continue |
| `<leader>ab` / `as` | Add buffer / send selection to Claude |
| `<leader>aa` / `ad` | Accept / deny Claude diff |
| `<leader>ak` | Skip a running typewriter animation |
| `Ctrl-z` / `Ctrl-y` | Undo / redo |
| `Ctrl-c` / `Ctrl-x` / `Ctrl-v` | Copy / cut / paste (system clipboard) |
| `Alt-a` | Select all |
| `Tab` (completion menu) | Accept suggestion |
| `Tab` (neo-tree) | Switch Files / Git |

## License

Based on the LazyVim starter, Apache-2.0 (see `LICENSE`).
