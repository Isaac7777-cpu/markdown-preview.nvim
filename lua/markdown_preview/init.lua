local M = {}

M.preview_file = function(filepath)
  vim.cmd("belowright split")
  vim.cmd("resize 20")
  local term_buf = vim.api.nvim_create_buf(false, true)
  local term_win = vim.api.nvim_get_current_win()

  vim.fn.termopen({ "glow", filepath }, {
    on_exit = function(_, code)
      if code ~= 0 then
        vim.api.nvim_err_writeln("Failed to render Markdown with glow.")
      end
    end,
  })

  vim.api.nvim_win_set_buf(term_win, term_buf)
end

M.preview_current_buffer = function()
  local tmpfile = vim.fn.tempname() .. ".md"
  vim.api.nvim_command("write! " .. tmpfile)
  M.preview_file(tmpfile)
end

vim.api.nvim_create_user_command("MarkdownPreview", function()
  M.preview_current_buffer()
end, {})

return M

