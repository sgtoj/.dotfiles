-- live grep with a path filter: `<grep query>  <path fuzzy query>`
--
-- behaves like the stock live_grep picker, but when the prompt contains a
-- double space, everything before it is the ripgrep query and everything
-- after it fuzzy-filters the results by file path (fzy, same algorithm the
-- find_files sorter uses)

local M = {}

M.live_grep = function()
  local pickers = require "telescope.pickers"
  local finders = require "telescope.finders"
  local make_entry = require "telescope.make_entry"
  local conf = require("telescope.config").values
  local sorters = require "telescope.sorters"
  local fzy = require "telescope.algos.fzy"

  local opts = {
    cwd = vim.uv.cwd(),
    entry_maker = nil, -- set below
  }
  opts.entry_maker = make_entry.gen_from_vimgrep(opts)

  local split_prompt = function(prompt)
    local grep_part, path_part = prompt:match "^(.-)%s%s+(.*)$"
    if grep_part then
      return grep_part, path_part
    end
    return prompt, nil
  end

  local grepper = finders.new_job(function(prompt)
    if not prompt or prompt == "" then
      return nil
    end
    local grep_part = split_prompt(prompt)
    if grep_part == "" then
      return nil
    end
    return vim.iter({
      conf.vimgrep_arguments,
      "-e",
      grep_part,
    }):flatten():totable()
  end, opts.entry_maker, nil, opts.cwd)

  local OFFSET = -fzy.get_score_floor()

  local path_sorter = sorters.Sorter:new {
    -- no prefix-based discard caching: editing the path part changes which
    -- entries match without the grep results changing
    discard = false,

    scoring_function = function(_, prompt, _, entry)
      local _, path_part = split_prompt(prompt)
      if not path_part or path_part == "" then
        return 1 -- no path filter: keep everything, natural rg order
      end

      local path = entry.filename or entry.value
      if not fzy.has_match(path_part, path) then
        return -1 -- filter out
      end

      local score = fzy.score(path_part, path)
      if score == fzy.get_score_min() then
        return 1
      end
      return 1 / (score + OFFSET)
    end,
  }

  pickers
    .new(opts, {
      prompt_title = "Live Grep",
      finder = grepper,
      previewer = conf.grep_previewer(opts),
      sorter = path_sorter,
    })
    :find()
end

return M
