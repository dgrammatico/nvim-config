-- Keep noice's ":" cmdline popup at the top-centre of the main editor pane (not the whole
-- screen, which includes the file tree). Recomputed every time ":" is pressed,
-- so it follows window resizes and the tree being shown/hidden.
local M = {}

local SIDE = { ["neo-tree"] = true, recentfiles = true }

local function editor_win()
  local function ok(w)
    if vim.api.nvim_win_get_config(w).relative ~= "" then return false end
    local b = vim.api.nvim_win_get_buf(w)
    return not SIDE[vim.bo[b].filetype] and vim.bo[b].buftype ~= "terminal"
  end
  local cur = vim.api.nvim_get_current_win()
  if ok(cur) then return cur end
  -- otherwise the biggest normal window
  local best, area = nil, 0
  for _, w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if ok(w) then
      local a = vim.api.nvim_win_get_width(w) * vim.api.nvim_win_get_height(w)
      if a > area then best, area = w, a end
    end
  end
  return best
end

function M.position(width)
  local win = editor_win()
  if not win then return nil end
  local p = vim.api.nvim_win_get_position(win)
  local w, h = vim.api.nvim_win_get_width(win), vim.api.nvim_win_get_height(win)
  return {
    row = p[1], -- top of the editor pane (above the start-screen logo)
    col = p[2] + math.max(0, math.floor((w - width) / 2)),
  }
end

local function apply()
  local ok_cfg, Config = pcall(require, "noice.config")
  if not ok_cfg or not Config.options or not Config.options.views then return end
  local view_cfg = Config.options.views.cmdline_popup or {}
  local width = (view_cfg.size and tonumber(view_cfg.size.width)) or 60
  local pos = M.position(width)
  if not pos then return end
  -- for the first time the popup is created
  view_cfg.relative = "editor"
  view_cfg.position = pos
  -- for the already-created popup (noice re-reads these each time it shows)
  local ok_view, View = pcall(require, "noice.view")
  if not ok_view then return end
  for _, v in ipairs(View._views or {}) do
    if v.opts and v.opts.view == "cmdline_popup" and v.view._view_opts then
      v.view._view_opts.relative = "editor"
      v.view._view_opts.position = vim.deepcopy(pos)
    end
  end
end

function M.setup()
  vim.api.nvim_create_autocmd("CmdlineEnter", {
    group = vim.api.nvim_create_augroup("cmdline_center", { clear = true }),
    callback = function() pcall(apply) end,
  })
end

return M
