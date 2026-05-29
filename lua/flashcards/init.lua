local config = require("flashcards.config")
local store = require("flashcards.store")
local ui = require("flashcards.ui")

local M = {}

local EXAMPLE = {
  "# example",
  "",
  "Q: What command starts a flashcard review session?",
  "A: :FlashReview",
  "",
  "Q: Which spaced-repetition algorithm does flashcards.nvim use?",
  "A: SM-2 (SuperMemo 2)",
  "",
  "Q: How do you add a new card from inside Neovim?",
  "A: :FlashAdd  (you'll be prompted for deck, front and back)",
  "",
}

local function maybe_create_example()
  if not config.options.create_example then
    return
  end
  if #store.list_decks() == 0 then
    store.ensure_dir()
    vim.fn.writefile(EXAMPLE, config.options.dir .. "/example.md")
  end
end

-- Prompt-driven card creation.
local function flash_add()
  local decks = store.list_decks()
  local default_deck = decks[1] and decks[1].name or "default"
  local deck = vim.fn.input("Deck: ", default_deck)
  if deck == "" then
    return
  end
  local front = vim.fn.input("Front (question): ")
  if front == "" then
    return
  end
  local back = vim.fn.input("Back (answer): ")
  if back == "" then
    return
  end
  local path = store.add_card(deck, front, back)
  vim.notify("Flashcards: added card to " .. vim.fn.fnamemodify(path, ":t"), vim.log.levels.INFO)
end

-- Open a deck file for direct editing. With no argument, pick via a prompt.
local function flash_edit(name)
  local decks = store.list_decks()
  if name and name ~= "" then
    local path = string.format("%s/%s.md", config.options.dir, name)
    vim.cmd("edit " .. vim.fn.fnameescape(path))
    return
  end
  if #decks == 0 then
    vim.notify("Flashcards: no decks yet. Add one with :FlashAdd", vim.log.levels.WARN)
    return
  end
  vim.ui.select(decks, {
    prompt = "Edit deck:",
    format_item = function(d)
      return d.name
    end,
  }, function(choice)
    if choice then
      vim.cmd("edit " .. vim.fn.fnameescape(choice.path))
    end
  end)
end

local function deck_names()
  local names = {}
  for _, d in ipairs(store.list_decks()) do
    table.insert(names, d.name)
  end
  return names
end

local registered = false
local function register_commands()
  if registered then
    return
  end
  registered = true

  vim.api.nvim_create_user_command("FlashReview", function(o)
    ui.review(o.args ~= "" and o.args or nil)
  end, {
    nargs = "?",
    complete = deck_names,
    desc = "Review due flashcards (optionally limited to a deck)",
  })

  vim.api.nvim_create_user_command("FlashAdd", flash_add, { desc = "Add a flashcard" })
  vim.api.nvim_create_user_command("FlashStats", ui.stats, { desc = "Show flashcard statistics" })

  vim.api.nvim_create_user_command("FlashEdit", function(o)
    flash_edit(o.args)
  end, {
    nargs = "?",
    complete = deck_names,
    desc = "Open a deck file for editing",
  })

  vim.api.nvim_create_user_command("FlashDecks", function()
    local names = deck_names()
    if #names == 0 then
      vim.notify("Flashcards: no decks yet. Add one with :FlashAdd", vim.log.levels.INFO)
    else
      vim.notify("Flashcards decks:\n  " .. table.concat(names, "\n  "), vim.log.levels.INFO)
    end
  end, { desc = "List flashcard decks" })
end

---@param opts FlashcardsConfig|nil
function M.setup(opts)
  config.setup(opts)
  store.ensure_dir()
  maybe_create_example()
  register_commands()
end

-- Convenience re-exports.
M.review = ui.review
M.stats = ui.stats

return M
