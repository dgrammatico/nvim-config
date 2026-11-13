-- Tab accepts the top completion suggestion (or the highlighted one).
-- With no menu open, Tab jumps to the next snippet field, otherwise inserts a normal tab.
return {
  "saghen/blink.cmp",
  opts = {
    keymap = {
      ["<Tab>"] = { "select_and_accept", "snippet_forward", "fallback" },
      ["<S-Tab>"] = { "snippet_backward", "fallback" },
    },
  },
}
