-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
--
-- Add any additional autocmds here
-- with `vim.api.nvim_create_autocmd`
--
-- Or remove existing autocmds by their group name (which is prefixed with `lazyvim_` for the defaults)
-- e.g. vim.api.nvim_del_augroup_by_name("lazyvim_wrap_spell")

-- Live reload with a typing animation + flash of changed lines (see lua/config/typewriter.lua)
require("config.typewriter").setup()

-- Jump the editor to whichever file Claude is about to edit (see lua/config/claude_jump.lua)
require("config.claude_jump").setup()

-- "Recent files" panel above the file tree (see lua/config/recent_files.lua)
require("config.recent_files").setup()

-- Closing the last editor window opens a fresh start screen (see lua/config/start_screen.lua)
require("config.start_screen").setup()

-- :terminal opens below the editor; :q closes terminals directly (see lua/config/terminal.lua)
require("config.terminal").setup()

-- Centre the ":" cmdline popup on the editor pane (see lua/config/cmdline_center.lua)
require("config.cmdline_center").setup()
