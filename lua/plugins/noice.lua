-- Cmdline popup: centred (fallback = top-centre of the screen; lua/config/cmdline_center.lua
-- re-centres it on the editor pane every time ":" is pressed)
return {
  "folke/noice.nvim",
  opts = {
    views = {
      cmdline_popup = {
        relative = "editor",
        position = { row = 0, col = "50%" },
        size = { width = 60, height = "auto" },
      },
    },
  },
}
