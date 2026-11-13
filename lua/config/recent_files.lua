-- "Recent files" panel pinned above the neo-tree file tree.
-- Shows the 5 most recently opened files; <CR>, l, o or double-click opens one
-- in the main editor window. Opens/closes together with the tree.
local M = {}
local MAX = 5
local ns = vim.api.nvim_create_namespace("recent_files_panel")
local mru, state = {}, { win = nil, buf = nil, paths = {} }

local function norm(p) return vim.fs.normalize(vim.fn.fnamemodify(p, ":p")) end

local function add(path)
  if path == "" or path:match("^%a+://") or vim.fn.filereadable(path) == 0 then return end
  path = norm(path)
  for i, p in ipairs(mru) do
    if p:lower() == path:lower() then table.remove(mru, i) break end
  end
  table.insert(mru, 1, path)
  while #mru > 50 do table.remove(mru) end
end

local function tree_win()
  for _, w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if vim.bo[vim.api.nvim_win_get_buf(w)].filetype == "neo-tree" then return w end
  end
end

local function render()
  local buf = state.buf
  if not (buf and vim.api.nvim_buf_is_valid(buf)) then return end
  local lines, paths, dirs = { " Recent files" }, {}, {}
  for _, p in ipairs(mru) do
    if #paths >= MAX then break end
    if vim.fn.filereadable(p) == 1 then
      table.insert(paths, p)
      table.insert(lines, ("  %d  %s"):format(#paths, vim.fn.fnamemodify(p, ":t")))
      table.insert(dirs, vim.fn.pathshorten(vim.fn.fnamemodify(p, ":~:h")))
    end
  end
  if #paths == 0 then table.insert(lines, "  (none yet)") end
  state.paths = paths
  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
  vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
  vim.api.nvim_buf_set_extmark(buf, ns, 0, 0, { end_col = #lines[1], hl_group = "Title" })
  for i, d in ipairs(dirs) do
    vim.api.nvim_buf_set_extmark(buf, ns, i, 2, { end_col = 3, hl_group = "Number" })
    vim.api.nvim_buf_set_extmark(buf, ns, i, 0, { virt_text = { { "  " .. d, "Comment" } }, virt_text_pos = "eol" })
  end
end

local function open_selected()
  local row = vim.api.nvim_win_get_cursor(0)[1]
  local p = state.paths[row - 1]
  if not p then return end
  if _G.ClaudeJump then
    _G.ClaudeJump(p) -- opens it in the main editor window
  else
    vim.cmd("wincmd l | edit " .. vim.fn.fnameescape(p))
  end
end

local function ensure_buf()
  if state.buf and vim.api.nvim_buf_is_valid(state.buf) then return state.buf end
  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].bufhidden = "hide"
  vim.bo[buf].filetype = "recentfiles"
  vim.bo[buf].modifiable = false
  for _, key in ipairs({ "<CR>", "l", "o", "<2-LeftMouse>" }) do
    vim.keymap.set("n", key, open_selected, { buffer = buf, nowait = true, desc = "Open recent file" })
  end
  for i = 1, MAX do
    vim.keymap.set("n", tostring(i), function()
      local p = state.paths[i]
      if p and _G.ClaudeJump then _G.ClaudeJump(p) end
    end, { buffer = buf, nowait = true, desc = "Open recent file " .. i })
  end
  vim.keymap.set("n", "q", "<cmd>Neotree close<cr>", { buffer = buf, nowait = true })
  state.buf = buf
  return buf
end

local function close_panel()
  if state.win and vim.api.nvim_win_is_valid(state.win) then
    pcall(vim.api.nvim_win_close, state.win, true)
  end
  state.win = nil
end

local function sync()
  local tw = tree_win()
  if not tw then return close_panel() end
  if state.win and vim.api.nvim_win_is_valid(state.win)
    and vim.api.nvim_win_get_tabpage(state.win) == vim.api.nvim_get_current_tabpage() then
    return render()
  end
  close_panel()
  local buf = ensure_buf()
  local win = vim.api.nvim_open_win(buf, false, { split = "above", win = tw, height = MAX + 1 })
  for opt, val in pairs({
    number = false, relativenumber = false, signcolumn = "no", foldcolumn = "0",
    cursorline = true, wrap = false, winfixheight = true, winfixwidth = true,
    winfixbuf = true, statusline = " ", list = false, spell = false,
  }) do
    pcall(function() vim.wo[win][opt] = val end)
  end
  state.win = win
  render()
end

function M.setup()
  for _, f in ipairs(vim.v.oldfiles) do
    if #mru >= 50 then break end
    if not f:match("^%a+://") and vim.fn.filereadable(f) == 1 then table.insert(mru, norm(f)) end
  end
  local group = vim.api.nvim_create_augroup("recent_files_panel", { clear = true })
  vim.api.nvim_create_autocmd("BufEnter", {
    group = group,
    callback = function(ev)
      if vim.bo[ev.buf].buftype == "" then
        add(vim.api.nvim_buf_get_name(ev.buf))
        vim.schedule(render)
      end
    end,
  })
  vim.api.nvim_create_autocmd({ "BufWinEnter", "FileType" }, {
    group = group,
    callback = function(ev)
      if vim.bo[ev.buf].filetype == "neo-tree" then vim.schedule(sync) end
    end,
  })
  vim.api.nvim_create_autocmd({ "WinClosed", "TabEnter" }, {
    group = group,
    callback = function() vim.schedule(sync) end,
  })
  -- the tree may already be open by the time this runs (startup race): sync now too
  vim.schedule(sync)
  vim.defer_fn(sync, 500)
end

return M
