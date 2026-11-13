-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here

-- Make sure winget-installed CLIs (rg, fd, lazygit, fzf, ...) and 7-Zip are on PATH,
-- even if Neovim was launched from a terminal started before they were installed.
local extra = {
  vim.fn.expand("$LOCALAPPDATA/Microsoft/WinGet/Links"),
  "C:/Program Files/7-Zip",
}
for _, dir in ipairs(extra) do
  if vim.fn.isdirectory(dir) == 1 and not vim.env.PATH:lower():find(dir:lower():gsub("/", "\\"), 1, true) then
    vim.env.PATH = dir .. ";" .. vim.env.PATH
  end
end

-- Unused remote-plugin providers (silences :checkhealth warnings, speeds startup)
vim.g.loaded_node_provider = 0
vim.g.loaded_perl_provider = 0
vim.g.loaded_python3_provider = 0
vim.g.loaded_ruby_provider = 0

-- Word wrap: long lines wrap at word boundaries, continuation lines keep the indent
vim.opt.wrap = true
vim.opt.linebreak = true
vim.opt.breakindent = true
vim.opt.showbreak = "↪ "
