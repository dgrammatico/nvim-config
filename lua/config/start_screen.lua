-- When :q / :wq closes the last editor window (leaving only the file tree,
-- recent-files panel or terminals), open a fresh LazyVim start screen instead.
-- Quitting the start screen itself (when nothing else is open) exits Neovim.
local M = {}

local START = { snacks_dashboard = true, dashboard = true, alpha = true, ministarter = true }
local SIDE = { ["neo-tree"] = true, recentfiles = true }

local function classify()
  local has_editor, tree, term
  for _, w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if vim.api.nvim_win_get_config(w).relative == "" then
      local b = vim.api.nvim_win_get_buf(w)
      local ft, bt = vim.bo[b].filetype, vim.bo[b].buftype
      if ft == "neo-tree" then tree = w end
      if bt == "terminal" and not term then term = w end
      if START[ft] or (bt == "" and not SIDE[ft]) then has_editor = true end
    end
  end
  return has_editor, tree, term
end

local function open_start_screen(tree, tree_width, term)
  if term then
    -- keep the stacked layout: start screen goes back above the terminal
    vim.api.nvim_set_current_win(term)
    vim.cmd("aboveleft new")
    local h = math.max(8, math.floor(vim.o.lines * 0.3))
    pcall(vim.api.nvim_win_set_height, term, h)
  else
    vim.api.nvim_set_current_win(tree)
    vim.cmd("botright vnew")
  end
  local win, buf = vim.api.nvim_get_current_win(), vim.api.nvim_get_current_buf()
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "wipe"
  if tree then pcall(vim.api.nvim_win_set_width, tree, tree_width or 34) end
  local ok = pcall(function() Snacks.dashboard.open({ win = win, buf = buf }) end)
  if not ok then vim.cmd("enew") end -- fallback: just an empty editor window
end

local function quit_if_safe()
  for _, b in ipairs(vim.api.nvim_list_bufs()) do
    if vim.bo[b].modified and vim.bo[b].buftype == "" then
      vim.notify("Unsaved changes - not quitting", vim.log.levels.WARN)
      return
    end
  end
  vim.cmd("qa!") -- nothing unsaved; also ends any terminal shells
end

function M.setup()
  vim.api.nvim_create_autocmd("WinClosed", {
    group = vim.api.nvim_create_augroup("start_screen_on_quit", { clear = true }),
    callback = function(ev)
      if vim.v.exiting ~= vim.NIL then return end
      local closed_ft = vim.bo[ev.buf].filetype
      local closed_start, closed_side = START[closed_ft] or false, SIDE[closed_ft] or false
      -- measure the tree now, before it expands into the space being freed
      local _, t = classify()
      local tree_width = t and vim.api.nvim_win_get_width(t)
      vim.schedule(function()
        if vim.v.exiting ~= vim.NIL or closed_side then return end
        local has_editor, tree, term = classify()
        if has_editor or not (tree or term) then return end
        if closed_start then
          quit_if_safe() -- leaving the start screen with nothing else open: quit
        else
          open_start_screen(tree, tree_width, term)
        end
      end)
    end,
  })
end

return M
