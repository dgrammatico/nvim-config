-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

-- Ctrl-h/j/k/l: move between Neovim windows; at Neovim's edge, hand off to the
-- neighbouring WezTerm pane (fastfetch / Claude) via `wezterm cli`.
local wez_dir = { h = "Left", j = "Down", k = "Up", l = "Right" }

local function navigate(key)
  local before = vim.fn.winnr()
  vim.cmd("wincmd " .. key)
  if vim.fn.winnr() == before and vim.env.WEZTERM_PANE then
    vim.system({ "wezterm", "cli", "activate-pane-direction", wez_dir[key] })
  end
end

for key in pairs(wez_dir) do
  vim.keymap.set("n", "<C-" .. key .. ">", function() navigate(key) end, { desc = "Go to window/pane " .. key })
  vim.keymap.set("t", "<C-" .. key .. ">", function()
    vim.cmd("stopinsert")
    vim.schedule(function() navigate(key) end)
  end, { desc = "Go to window/pane " .. key })
end

-- Tell WezTerm this pane is running Neovim (so WezTerm forwards Ctrl-h/j/k/l to us)
local function set_is_nvim(v)
  io.stdout:write(string.format("\027]1337;SetUserVar=IS_NVIM=%s\007", vim.base64.encode(v)))
end
set_is_nvim("true")
vim.api.nvim_create_autocmd({ "VimLeavePre", "VimSuspend" }, { callback = function() set_is_nvim("false") end })
vim.api.nvim_create_autocmd("VimResume", { callback = function() set_is_nvim("true") end })

-- Alt+c toggles Claude from anywhere, including from inside Claude
vim.keymap.set({ "n", "t" }, "<M-c>", "<cmd>ClaudeCodeFocus<cr>", { desc = "Toggle/focus Claude" })

-- Jumping back into a terminal window drops you straight into typing mode
vim.api.nvim_create_autocmd({ "BufEnter", "WinEnter" }, {
  pattern = "term://*",
  callback = function() vim.cmd("startinsert") end,
})

-- Windows-style editing shortcuts (all use the system clipboard)
local map = vim.keymap.set
-- Undo / redo
map("n", "<C-z>", "u", { desc = "Undo" })
map("i", "<C-z>", "<C-o>u", { desc = "Undo" })
map("n", "<C-y>", "<C-r>", { desc = "Redo" })
map("i", "<C-y>", "<C-o><C-r>", { desc = "Redo" })
-- Select all (Ctrl-a is taken by WezTerm, so Alt-a)
map({ "n", "i", "v" }, "<M-a>", "<Esc>ggVG", { desc = "Select all" })
-- Copy: selection in visual mode, current line in normal mode
map("v", "<C-c>", '"+y', { desc = "Copy" })
map("n", "<C-c>", '"+yy', { desc = "Copy line" })
-- Cut
map("v", "<C-x>", '"+d', { desc = "Cut" })
-- Paste (replaces the selection in visual mode)
map("n", "<C-v>", '"+P', { desc = "Paste" })
map("v", "<C-v>", '"_d"+P', { desc = "Paste over selection" })
map("i", "<C-v>", "<C-r><C-o>+", { desc = "Paste" })

-- Accelerating arrow keys: a tap moves 1 line; holding Up/Down speeds up (2 -> 4 -> 6 lines per repeat)
local accel = { last = 0, count = 0 }
local function accel_move(motion)
  return function()
    if vim.v.count > 0 then return motion end
    local now = vim.uv.now()
    accel.count = (now - accel.last < 90) and accel.count + 1 or 0
    accel.last = now
    local c = accel.count
    local step = c < 6 and 1 or c < 15 and 2 or c < 30 and 4 or 6
    return step == 1 and ("g" .. motion) or (step .. motion)
  end
end
map({ "n", "v" }, "<Down>", accel_move("j"), { expr = true, desc = "Down (accelerates when held)" })
map({ "n", "v" }, "<Up>", accel_move("k"), { expr = true, desc = "Up (accelerates when held)" })
