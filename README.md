# flashcards.nvim

A tiny, dependency-free flashcard app for Neovim with [SM-2][sm2] spaced
repetition. Decks are plain Markdown files you can edit by hand, and review
scheduling is persisted as JSON in your data directory.

## Features

- 📇 Decks are plain `.md` files — edit, version, and sync them however you like
- 🧠 SM-2 spaced-repetition scheduling (per-card easiness factor & intervals)
- 🪟 Distraction-free floating review window
- ⌨️ Grade recall with `1`/`2`/`3`/`4`, reveal with `<Space>`
- 🚫 No external dependencies (uses only built-in Neovim APIs)

## Requirements

- Neovim ≥ 0.10 (uses `vim.json`, `vim.uv`)

## Installation

### [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  "samuelnihoul/flashcards.nvim",
  opts = {
    -- where decks (*.md) and the .state.json schedule live
    dir = vim.fn.stdpath("data") .. "/flashcards",
    new_per_session = 20,
    max_reviews = 200,
  },
  cmd = { "FlashReview", "FlashAdd", "FlashStats", "FlashEdit", "FlashDecks" },
}
```

`opts` is passed straight to `require("flashcards").setup()`.

## Usage

| Command                 | Description                                            |
| ----------------------- | ------------------------------------------------------ |
| `:FlashReview [deck]`   | Start a review session (optionally limited to a deck)  |
| `:FlashAdd`             | Add a card (prompts for deck, front, back)             |
| `:FlashEdit [deck]`     | Open a deck file for hand-editing                      |
| `:FlashDecks`           | List your decks                                        |
| `:FlashStats`           | Show due / new / learned counts per deck               |

### In the review window

| Key       | Action                          |
| --------- | ------------------------------- |
| `<Space>` | Reveal the answer               |
| `1`       | Again (forgot — reset the card) |
| `2`       | Hard                            |
| `3`       | Good                            |
| `4`       | Easy                            |
| `q`/`Esc` | End the session                 |

## Deck format

A deck is just a Markdown file. A line starting with `Q:` begins a card's
front; `A:` begins its answer. Both may span multiple lines (continuation
lines belong to whichever section is currently open).

```markdown
# capitals

Q: What is the capital of France?
A: Paris

Q: What is the capital of Japan?
A: Tokyo
```

Card identity is derived from the deck name and the front text, so you can
freely reorder cards or edit answers without losing scheduling history.

## Configuration

```lua
require("flashcards").setup({
  dir = vim.fn.stdpath("data") .. "/flashcards",
  new_per_session = 20,
  max_reviews = 200,
  create_example = true,
  keymaps = {
    reveal = "<Space>",
    again = "1",
    hard = "2",
    good = "3",
    easy = "4",
    quit = "q",
  },
})
```

## License

MIT

[sm2]: https://en.wikipedia.org/wiki/SuperMemo#Description_of_SM-2_algorithm
