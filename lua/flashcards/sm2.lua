-- A small implementation of the SuperMemo SM-2 spaced-repetition algorithm.
-- See https://www.supermemo.com/en/blog/application-of-a-computer-to-improve-the-results-obtained-in-working-with-the-supermemo-method
local M = {}

local DAY = 24 * 60 * 60

-- Default scheduling state for a card that has never been reviewed.
function M.new_state()
  return {
    ef = 2.5, -- easiness factor
    interval = 0, -- days until next review
    reps = 0, -- number of consecutive correct recalls
  }
end

local function today_ts()
  local t = os.date("*t")
  return os.time({ year = t.year, month = t.month, day = t.day, hour = 0 })
end

---@param days integer
function M.date_in(days)
  return os.date("%Y-%m-%d", today_ts() + days * DAY)
end

function M.today()
  return os.date("%Y-%m-%d", today_ts())
end

-- Update `state` (mutated in place) given a recall quality grade 0..5.
-- Grades < 3 are treated as a failure: the card is reset and shown again soon.
---@param state table
---@param quality integer
function M.review(state, quality)
  quality = math.max(0, math.min(5, quality))

  if quality < 3 then
    state.reps = 0
    state.interval = 1
  else
    if state.reps == 0 then
      state.interval = 1
    elseif state.reps == 1 then
      state.interval = 6
    else
      state.interval = math.ceil(state.interval * state.ef)
    end
    state.reps = state.reps + 1
  end

  -- Update the easiness factor and clamp it to the conventional 1.3 floor.
  state.ef = state.ef + (0.1 - (5 - quality) * (0.08 + (5 - quality) * 0.02))
  if state.ef < 1.3 then
    state.ef = 1.3
  end

  state.due = M.date_in(state.interval)
  state.reviewed = M.today()
  return state
end

return M
