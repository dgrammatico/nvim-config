-- :terminal / :term open in a split BELOW the editor (~30% height) instead of
-- replacing the current window, and :q / :wq / :x in a terminal close it
-- straight away (no "E948: Job still running").
local M = {}

local SIDE = { ["neo-tree"] = true, recentfiles = true }

function M.open(args)
  -- never split the file tree / recent-files panel; use the editor next to it
  if SIDE[vim.bo.filetype] then vim.cmd("wincmd l") end
  local height = math.max(8, math.floor(vim.o.lines * 0.3))
  vim.cmd("belowright " .. height .. "split")
  vim.cmd("terminal" .. (args ~= "" and (" " .. args) or ""))
  vim.cmd("startinsert")
end

function M.setup()
  vim.api.nvim_create_user_command("Term", function(o) M.open(o.args) end,
    { nargs = "*", complete = "shellcmd", desc = "Terminal in a split below" })
  -- route the built-in :terminal / :term to :Term (only when typed as the command itself)
  for _, cmd in ipairs({ "terminal", "term" }) do
    vim.cmd(("cnoreabbrev <expr> %s (getcmdtype() ==# ':' && getcmdline() ==# '%s') ? 'Term' : '%s'"):format(cmd, cmd, cmd))
  end

  vim.api.nvim_create_autocmd("TermOpen", {
    group = vim.api.nvim_create_augroup("terminal_quit", { clear = true }),
    callback = function(ev)
      vim.bo[ev.buf].bufhidden = "wipe"
      -- Esc Esc (quickly) leaves typing mode so you can use :q etc.; a single Esc still reaches the program
      vim.keymap.set("t", "<Esc><Esc>", "<C-\\><C-n>", { buffer = ev.buf, desc = "Leave terminal typing mode" })
      -- :q, :wq, :x in a terminal = close it (and end its shell)
      for _, q in ipairs({ "q", "wq", "x", "quit" }) do
        vim.cmd(("cnoreabbrev <buffer> <expr> %s (getcmdtype() ==# ':' && getcmdline() ==# '%s') ? 'q!' : '%s'"):format(q, q, q))
      end
    end,
  })
end

return M
