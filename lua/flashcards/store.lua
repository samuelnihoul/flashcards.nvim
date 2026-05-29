local config = require("flashcards.config")

local M = {}

local function dir()
  return config.options.dir
end

local function state_path()
  return dir() .. "/.state.json"
end

-- Ensure the flashcards directory exists.
function M.ensure_dir()
  local d = dir()
  if vim.fn.isdirectory(d) == 0 then
    vim.fn.mkdir(d, "p")
  end
  return d
end

-- A stable identifier for a card, derived from its deck and front text so that
-- scheduling state survives reordering and editing of the answer.
function M.card_id(deck, front)
  -- A record-separator (0x1E) keeps deck/front apart without using a NUL byte,
  -- which Neovim would coerce into a Blob when passed to vim.fn.sha256.
  return vim.fn.sha256(deck .. "\30" .. front)
end

-- List deck files (*.md) in the flashcards directory.
function M.list_decks()
  local decks = {}
  for _, path in ipairs(vim.fn.globpath(dir(), "*.md", false, true)) do
    table.insert(decks, {
      path = path,
      name = vim.fn.fnamemodify(path, ":t:r"),
    })
  end
  table.sort(decks, function(a, b)
    return a.name < b.name
  end)
  return decks
end

-- Parse a deck file into a list of { front, back } cards.
-- Format: a line starting with "Q:" begins a card front, "A:" its answer.
-- Continuation lines extend whichever section is currently open, so both the
-- front and the back may span multiple lines.
function M.read_deck(path)
  local cards = {}
  local ok, lines = pcall(vim.fn.readfile, path)
  if not ok then
    return cards
  end

  local cur, section
  local function append(field, line)
    cur[field] = cur[field] == "" and line or (cur[field] .. "\n" .. line)
  end

  for _, line in ipairs(lines) do
    local q = line:match("^%s*[Qq]:%s?(.*)$")
    local a = line:match("^%s*[Aa]:%s?(.*)$")
    if q ~= nil then
      if cur and cur.front ~= "" then
        table.insert(cards, cur)
      end
      cur = { front = q, back = "" }
      section = "front"
    elseif a ~= nil and cur then
      cur.back = a
      section = "back"
    elseif cur and line:match("%S") then
      append(section == "front" and "front" or "back", line)
    end
  end
  if cur and cur.front ~= "" then
    table.insert(cards, cur)
  end
  return cards
end

-- Load every card across every deck, tagged with its deck name and id.
function M.all_cards()
  local cards = {}
  for _, deck in ipairs(M.list_decks()) do
    for _, card in ipairs(M.read_deck(deck.path)) do
      card.deck = deck.name
      card.id = M.card_id(deck.name, card.front)
      table.insert(cards, card)
    end
  end
  return cards
end

-- Load the persisted scheduling state keyed by card id.
function M.load_state()
  local ok, content = pcall(vim.fn.readfile, state_path())
  if not ok or #content == 0 then
    return {}
  end
  local decoded
  local good = pcall(function()
    decoded = vim.json.decode(table.concat(content, "\n"))
  end)
  return (good and type(decoded) == "table") and decoded or {}
end

-- Persist scheduling state.
function M.save_state(state)
  M.ensure_dir()
  vim.fn.writefile({ vim.json.encode(state) }, state_path())
end

-- Render a field's (possibly multi-line) text with a "Q: "/"A: " prefix on the
-- first line and raw continuation lines after it.
local function render_field(prefix, text)
  local out = {}
  for line in vim.gsplit(text, "\n", { plain = true }) do
    table.insert(out, #out == 0 and (prefix .. line) or line)
  end
  return out
end

-- Append a new card to a deck, creating the deck file if necessary.
function M.add_card(deck_name, front, back)
  M.ensure_dir()
  local path = string.format("%s/%s.md", dir(), deck_name)
  local lines
  if vim.fn.filereadable(path) == 1 then
    lines = vim.fn.readfile(path)
    if #lines > 0 and lines[#lines]:match("%S") then
      table.insert(lines, "")
    end
  else
    lines = { "# " .. deck_name, "" }
  end

  vim.list_extend(lines, render_field("Q: ", front))
  vim.list_extend(lines, render_field("A: ", back))
  table.insert(lines, "")

  vim.fn.writefile(lines, path)
  return path
end

return M
