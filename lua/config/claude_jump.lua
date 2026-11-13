-- When Claude is about to edit a file, show it in the main editor window.
-- A Claude Code hook (~/.claude/hooks/nvim-jump.ps1) calls ClaudeJump(path) over
-- Neovim's RPC pipe; the pipe address is published to a small file so the hook
-- can find the most recently focused Neovim.
local M = {}

local server_file = vim.fn.stdpath("data") .. "/claude-jump-server"

local function publish()
  if vim.v.servername ~= "" then
    pcall(vim.fn.writefile, { vim.v.servername }, server_file)
  end
end

-- Start screens that should be replaced by the file, not split next to
local START_SCREENS = { snacks_dashboard = true, dashboard = true, alpha = true, ministarter = true, starter = true }

local function is_editor_win(win)
  local buf = vim.api.nvim_win_get_buf(win)
  local cfg = vim.api.nvim_win_get_config(win)
  if cfg.relative ~= "" then return false end -- floating window
  local ft, bt = vim.bo[buf].filetype, vim.bo[buf].buftype
  if START_SCREENS[ft] then return true end
  return bt == "" and ft ~= "neo-tree" and ft ~= "recentfiles"
end

local function pick_window()
  local cur = vim.api.nvim_get_current_win()
  if is_editor_win(cur) then return cur end
  for _, w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if is_editor_win(w) then return w end
  end
end

function _G.ClaudeJump(path)
  vim.schedule(function()
    path = vim.fs.normalize(path)
    -- already showing in some window? just focus it
    for _, w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
      local name = vim.fs.normalize(vim.api.nvim_buf_get_name(vim.api.nvim_win_get_buf(w)))
      if name:lower() == path:lower() then
        vim.api.nvim_set_current_win(w)
        return
      end
    end
    local win = pick_window()
    if not win then
      -- only the tree / terminals are open: open a fresh split to the right
      vim.cmd("botright vsplit")
      win = vim.api.nvim_get_current_win()
    end
    vim.api.nvim_set_current_win(win)
    pcall(vim.cmd, "edit " .. vim.fn.fnameescape(path))
  end)
  return 1
end

function M.setup()
  local group = vim.api.nvim_create_augroup("claude_jump", { clear = true })
  vim.api.nvim_create_autocmd({ "VimEnter", "FocusGained", "BufEnter", "CursorHold" }, { group = group, callback = publish })
  vim.api.nvim_create_autocmd("VimLeavePre", {
    group = group,
    callback = function()
      local ok, lines = pcall(vim.fn.readfile, server_file)
      if ok and lines[1] == vim.v.servername then pcall(vim.fn.delete, server_file) end
    end,
  })
  publish()
end

return M
