local config = require("flashcards.config")
local store = require("flashcards.store")
local sm2 = require("flashcards.sm2")

local M = {}

-- Build the review queue: cards that are due (reps > 0 and due <= today) plus a
-- capped number of brand-new cards, limited overall by `max_reviews`.
local function build_queue(deck_filter)
  local opts = config.options
  local state = store.load_state()
  local today = sm2.today()

  local due, fresh = {}, {}
  for _, card in ipairs(store.all_cards()) do
    if not deck_filter or card.deck == deck_filter then
      local s = state[card.id]
      if not s then
        table.insert(fresh, card)
      elseif (s.due or today) <= today then
        table.insert(due, card)
      end
    end
  end

  -- Show overdue cards first, then introduce new material.
  local queue = {}
  vim.list_extend(queue, due)
  for i = 1, math.min(#fresh, opts.new_per_session) do
    table.insert(queue, fresh[i])
  end
  while #queue > opts.max_reviews do
    table.remove(queue)
  end
  return queue, state
end

local function center(lines, width)
  local out = {}
  for _, line in ipairs(lines) do
    local pad = math.max(0, math.floor((width - vim.fn.strdisplaywidth(line)) / 2))
    table.insert(out, string.rep(" ", pad) .. line)
  end
  return out
end

-- Open a review session. `deck_filter` (string|nil) restricts to one deck.
function M.review(deck_filter)
  local queue, state = build_queue(deck_filter)
  if #queue == 0 then
    vim.notify("Flashcards: nothing due. 🎉", vim.log.levels.INFO)
    return
  end

  local km = config.options.keymaps
  local width = math.min(math.floor(vim.o.columns * 0.7), 80)
  local height = math.min(math.floor(vim.o.lines * 0.6), 20)

  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].bufhidden = "wipe"
  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    style = "minimal",
    border = "rounded",
    title = " Flashcards ",
    title_pos = "center",
    width = width,
    height = height,
    row = math.floor((vim.o.lines - height) / 2 - 1),
    col = math.floor((vim.o.columns - width) / 2),
  })
  vim.wo[win].wrap = true

  local idx = 1
  local revealed = false
  local total = #queue

  local function close()
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
    store.save_state(state)
  end

  local function render()
    local card = queue[idx]
    local body = {}
    vim.api.nvim_win_set_config(win, {
      title = string.format(" Flashcards — %s — %d/%d ", card.deck, idx, total),
      title_pos = "center",
    })

    local blank = math.max(1, math.floor(height / 4))
    for _ = 1, blank do
      table.insert(body, "")
    end
    vim.list_extend(body, center(vim.split(card.front, "\n"), width))

    if revealed then
      table.insert(body, "")
      table.insert(body, center({ string.rep("─", math.floor(width / 2)) }, width)[1])
      table.insert(body, "")
      vim.list_extend(body, center(vim.split(card.back, "\n"), width))
    end

    -- Footer help, pinned near the bottom.
    while #body < height - 2 do
      table.insert(body, "")
    end
    if revealed then
      table.insert(
        body,
        center({ ("[%s] again   [%s] hard   [%s] good   [%s] easy   [%s] quit"):format(
          km.again, km.hard, km.good, km.easy, km.quit
        ) }, width)[1]
      )
    else
      table.insert(body, center({ ("[%s] reveal answer   [%s] quit"):format(km.reveal, km.quit) }, width)[1])
    end

    vim.bo[buf].modifiable = true
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, body)
    vim.bo[buf].modifiable = false
  end

  local function next_card()
    revealed = false
    idx = idx + 1
    if idx > total then
      close()
      vim.notify(("Flashcards: session complete — %d card(s) reviewed. ✅"):format(total), vim.log.levels.INFO)
      return
    end
    render()
  end

  local function grade(quality)
    if not revealed then
      return
    end
    local card = queue[idx]
    local s = state[card.id] or sm2.new_state()
    sm2.review(s, quality)
    s.front, s.deck = card.front, card.deck
    state[card.id] = s
    next_card()
  end

  local function map(lhs, fn)
    vim.keymap.set("n", lhs, fn, { buffer = buf, nowait = true, silent = true })
  end

  map(km.reveal, function()
    if not revealed then
      revealed = true
      render()
    end
  end)
  map(km.again, function() grade(0) end)
  map(km.hard, function() grade(3) end)
  map(km.good, function() grade(4) end)
  map(km.easy, function() grade(5) end)
  map(km.quit, close)
  map("<Esc>", close)

  render()
end

-- Print a summary of decks and scheduling state.
function M.stats()
  local state = store.load_state()
  local today = sm2.today()
  local decks = {}
  local due_total, new_total, seen_total = 0, 0, 0

  for _, card in ipairs(store.all_cards()) do
    local d = decks[card.deck] or { total = 0, due = 0, new = 0 }
    d.total = d.total + 1
    local s = state[card.id]
    if not s then
      d.new = d.new + 1
      new_total = new_total + 1
    else
      seen_total = seen_total + 1
      if (s.due or today) <= today then
        d.due = d.due + 1
        due_total = due_total + 1
      end
    end
    decks[card.deck] = d
  end

  local lines = { "Flashcards stats (" .. today .. ")", "" }
  local names = vim.tbl_keys(decks)
  table.sort(names)
  for _, name in ipairs(names) do
    local d = decks[name]
    table.insert(lines, ("  %-20s total %3d   due %3d   new %3d"):format(name, d.total, d.due, d.new))
  end
  if #names == 0 then
    table.insert(lines, "  (no decks yet — add one with :FlashAdd)")
  end
  table.insert(lines, "")
  table.insert(lines, ("  Totals: due %d   new %d   learned %d"):format(due_total, new_total, seen_total))
  vim.notify(table.concat(lines, "\n"), vim.log.levels.INFO)
end

return M
