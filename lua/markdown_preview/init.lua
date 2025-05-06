local M = {}

M.preview_file = function(filepath)
  -- Create a new unlisted scratch buffer
  local term_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_option(term_buf, "filetype", "")
  pcall(vim.treesitter.stop, term_buf)

  -- Open the terminal buffer in a new horizontal split
  vim.cmd("belowright split")
  vim.cmd("resize 20")
  local win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(win, term_buf)

  -- Launch glow
  vim.fn.termopen({ "glow", filepath }, {
    on_exit = function(_, code)
      if code ~= 0 then
        vim.api.nvim_err_writeln("Failed to render Markdown with glow.")
      end
    end,
  })
end

M.preview_current_buffer = function()
  local tmpfile = vim.fn.tempname() .. ".md"
  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  local fd = assert(io.open(tmpfile, "w"))
  fd:write(table.concat(lines, "\n"))
  fd:close()

  M.preview_file(tmpfile)
end

vim.api.nvim_create_user_command("MarkdownPreviewSplit", function()
  M.preview_current_buffer()
end, {})

return M
