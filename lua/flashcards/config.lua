local M = {}

---@class FlashcardsConfig
M.defaults = {
  -- Directory where decks (*.md) and the review state (.state.json) live.
  dir = vim.fn.stdpath("data") .. "/flashcards",
  -- Maximum number of brand-new cards introduced in a single review session.
  new_per_session = 20,
  -- Hard cap on the number of cards shown in a single review session.
  max_reviews = 200,
  -- Create a small example deck the first time the plugin runs with an empty dir.
  create_example = true,
  -- Buffer-local keymaps used inside the review window.
  keymaps = {
    reveal = "<Space>", -- reveal the answer
    again = "1", -- forgot it (reset)
    hard = "2", -- recalled with serious difficulty
    good = "3", -- recalled correctly
    easy = "4", -- recalled easily
    quit = "q", -- end the session
  },
}

M.options = vim.deepcopy(M.defaults)

---@param opts table|nil
function M.setup(opts)
  M.options = vim.tbl_deep_extend("force", vim.deepcopy(M.defaults), opts or {})
  return M.options
end

return M
