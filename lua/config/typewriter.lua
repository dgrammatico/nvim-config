-- Typewriter reload: when a file you have open changes on disk (e.g. Claude edits it),
-- replay the changed lines as if they were being typed, then flash them.
-- Falls back to an instant reload + flash if anything goes wrong.
-- Only touches buffers WITHOUT unsaved edits. <leader>ak skips a running animation.
local M = {}

M.opts = {
  poll_ms = 250, -- how often to look for changes on disk
  tick_ms = 8, -- animation frame interval
  max_ms = 1200, -- an edit of any size finishes typing within roughly this long
  min_chars = 6, -- minimum characters typed per frame
  flash_ms = 1500, -- how long changed lines stay highlighted afterwards
}

local ns = vim.api.nvim_create_namespace("claude_typewriter")
local mtimes, running = {}, {}

local function mtime(path)
  local st = vim.uv.fs_stat(path)
  return st and (st.mtime.sec * 1e9 + st.mtime.nsec) or 0 -- 0 = file doesn't exist (yet)
end

local function watchable(buf)
  return vim.api.nvim_buf_is_loaded(buf)
    and vim.bo[buf].buftype == ""
    and vim.api.nvim_buf_get_name(buf) ~= ""
end

local function read_lines(buf, path)
  local ok, lines = pcall(vim.fn.readfile, path)
  if not ok then return nil end
  if vim.bo[buf].fileformat == "dos" then
    for i, l in ipairs(lines) do lines[i] = l:gsub("\r$", "") end
  end
  return lines
end

-- Make Neovim's idea of the file match disk again, without moving anyone's view
local function sync(buf)
  local views = {}
  for _, w in ipairs(vim.fn.win_findbuf(buf)) do
    views[w] = vim.api.nvim_win_call(w, vim.fn.winsaveview)
  end
  vim.api.nvim_buf_call(buf, function() vim.cmd("silent! edit!") end)
  for w, v in pairs(views) do
    pcall(vim.api.nvim_win_call, w, function() vim.fn.winrestview(v) end)
  end
  mtimes[buf] = mtime(vim.api.nvim_buf_get_name(buf))
end

local function flash(buf, ranges)
  vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
  local n = vim.api.nvim_buf_line_count(buf)
  for _, r in ipairs(ranges) do
    for l = r[1], math.min(r[2], n) - 1 do
      pcall(vim.api.nvim_buf_set_extmark, buf, ns, l, 0, { line_hl_group = "DiffText", priority = 200 })
    end
  end
  vim.defer_fn(function()
    if vim.api.nvim_buf_is_valid(buf) then vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1) end
  end, M.opts.flash_ms)
end

local function ranges_of(hunks)
  local r = {}
  for _, h in ipairs(hunks) do
    if h[4] > 0 then table.insert(r, { h[3] - 1, h[3] - 1 + h[4] }) end
  end
  return r
end

local function instant(buf, hunks)
  sync(buf)
  flash(buf, ranges_of(hunks))
end

local function follow(buf, row)
  for _, w in ipairs(vim.fn.win_findbuf(buf)) do
    pcall(vim.api.nvim_win_set_cursor, w, { row + 1, 0 })
  end
end

local function animate(buf, new, hunks)
  local o = M.opts
  local total = 0
  for _, h in ipairs(hunks) do
    for i = h[3], h[3] + h[4] - 1 do total = total + #new[i] + 1 end
  end
  local st = { hi = 1, k = 0, col = 0, started = false, skip = false, typed = 0, deadline = vim.uv.now() + o.max_ms }
  running[buf] = st
  local timer = vim.uv.new_timer()

  local function set(fn)
    vim.bo[buf].modifiable = true
    pcall(vim.cmd, "undojoin")
    fn()
  end

  local function finish(ok)
    timer:stop(); timer:close()
    running[buf] = nil
    if not vim.api.nvim_buf_is_valid(buf) then return end
    vim.bo[buf].modifiable = true
    if ok then
      sync(buf)
      flash(buf, ranges_of(hunks))
    else
      instant(buf, hunks)
    end
  end

  local function step()
    if not vim.api.nvim_buf_is_valid(buf) then return finish(false) end
    -- adaptive speed: spread what's left over the time left, so every edit finishes on time
    local left_ms = math.max(o.tick_ms, st.deadline - vim.uv.now())
    local budget = st.skip and math.huge
      or math.max(o.min_chars, math.ceil((total - st.typed) / (left_ms / o.tick_ms)))
    while budget > 0 do
      local h = hunks[st.hi]
      if not h then return finish(true) end
      local row0 = (h[4] > 0) and (h[3] - 1) or h[3]
      if not st.started then
        set(function()
          vim.api.nvim_buf_set_lines(buf, row0, row0 + h[2], false, h[4] > 0 and { "" } or {})
        end)
        st.started, st.k, st.col = true, 0, 0
      end
      if st.k >= h[4] then
        st.hi, st.started = st.hi + 1, false
      else
        local target = new[h[3] + st.k]
        local take = math.min(budget, #target - st.col)
        if take > 0 then
          local col = st.col + take
          if col < #target then col = col + vim.str_utf_end(target, col) end -- don't split a character
          st.col = col
          set(function()
            vim.api.nvim_buf_set_lines(buf, row0 + st.k, row0 + st.k + 1, false, { target:sub(1, col) })
          end)
          budget = budget - take
          st.typed = st.typed + take
        end
        if st.col >= #target then
          st.k, st.col = st.k + 1, 0
          budget = budget - 1
          st.typed = st.typed + 1
          if st.k < h[4] then
            set(function() vim.api.nvim_buf_set_lines(buf, row0 + st.k, row0 + st.k, false, { "" }) end)
          end
        end
        vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
        local line = math.min(row0 + st.k, vim.api.nvim_buf_line_count(buf) - 1)
        pcall(vim.api.nvim_buf_set_extmark, buf, ns, line, 0, { line_hl_group = "DiffText" })
        follow(buf, line)
      end
    end
    vim.bo[buf].modifiable = false -- keep your keystrokes out of the animation
  end

  timer:start(0, o.tick_ms, vim.schedule_wrap(function()
    local ok = pcall(step)
    if not ok and running[buf] then finish(false) end
  end))
end

local function on_disk_change(buf)
  local path = vim.api.nvim_buf_get_name(buf)
  local new = read_lines(buf, path)
  if not new then return end
  local old = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  local hunks = vim.diff(table.concat(old, "\n") .. "\n", table.concat(new, "\n") .. "\n",
    { result_type = "indices", algorithm = "histogram" })
  if #hunks == 0 then return sync(buf) end
  local ok = pcall(animate, buf, new, hunks)
  if not ok then
    running[buf] = nil
    pcall(instant, buf, hunks)
  end
end

local function poll()
  local mode = vim.api.nvim_get_mode().mode
  if mode:find("^c") or vim.fn.getcmdwintype() ~= "" then return end
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if watchable(buf) and not running[buf] then
      local m = mtime(vim.api.nvim_buf_get_name(buf))
      if mtimes[buf] == nil then
        mtimes[buf] = m
      elseif m and m ~= mtimes[buf] then
        mtimes[buf] = m
        if not vim.bo[buf].modified then on_disk_change(buf) end
      end
    end
  end
end

function M.setup()
  vim.o.autoread = true
  -- LazyVim's own focus-based reload would race the animation; we handle it here instead
  pcall(vim.api.nvim_del_augroup_by_name, "lazyvim_checktime")

  local group = vim.api.nvim_create_augroup("claude_typewriter", { clear = true })
  vim.api.nvim_create_autocmd({ "BufReadPost", "BufNewFile", "BufWritePost" }, {
    group = group,
    callback = function(ev) mtimes[ev.buf] = mtime(vim.api.nvim_buf_get_name(ev.buf)) end,
  })
  vim.api.nvim_create_autocmd({ "FocusGained", "BufEnter" }, { group = group, callback = poll })

  local t = vim.uv.new_timer()
  t:start(M.opts.poll_ms, M.opts.poll_ms, vim.schedule_wrap(poll))

  vim.keymap.set("n", "<leader>ak", function()
    for _, st in pairs(running) do st.skip = true end
  end, { desc = "Skip typing animation" })
end

return M
