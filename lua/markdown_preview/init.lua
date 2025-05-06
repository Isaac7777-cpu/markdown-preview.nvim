local M = {}

-- Helper: Write buffer to tempfile
local function write_tempfile()
	local tmpfile = vim.fn.tempname() .. ".md"
	local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
	local fd = assert(io.open(tmpfile, "w"))
	fd:write(table.concat(lines, "\n"))
	fd:close()
	return tmpfile
end

-- Used to remove left over buffer and also enable some command in preview
local function setup_preview_buffer(bufnr, close_cmd)
  vim.bo[bufnr].bufhidden = "wipe"
  vim.api.nvim_buf_set_keymap(bufnr, "n", "q", "<cmd>" .. close_cmd .. "<CR>", {
    noremap = true,
    silent = true,
  })
end

-- Core terminal previewer
local function run_glow(term_buf, filepath)
	vim.api.nvim_buf_set_option(term_buf, "filetype", "")
	pcall(vim.treesitter.stop, term_buf)
	vim.fn.termopen({ "glow", filepath }, {
		on_exit = function(_, code)
			if code ~= 0 then
				vim.api.nvim_err_writeln("glow exited with code " .. code)
			end
		end,
	})
end

-- Split preview
function M.preview_split()
	local filepath = write_tempfile()
	vim.cmd("belowright split")
	vim.cmd("resize 20")

	local term_buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_win_set_buf(0, term_buf)
    setup_preview_buffer(term_buf, "close")

	run_glow(term_buf, filepath)
end

-- Tab preview
function M.preview_tab()
	local filepath = write_tempfile()
	vim.cmd("tabnew")
	local term_buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_win_set_buf(0, term_buf)
    setup_preview_buffer(term_buf, "tabclose")
	run_glow(term_buf, filepath)
end

-- Popup preview
function M.preview_popup()
	local filepath = write_tempfile()
	local width = math.floor(vim.o.columns * 0.8)
	local height = math.floor(vim.o.lines * 0.7)
	local row = math.floor((vim.o.lines - height) / 2)
	local col = math.floor((vim.o.columns - width) / 2)

	local term_buf = vim.api.nvim_create_buf(false, true)
	local opts = {
		relative = "editor",
		row = row,
		col = col,
		width = width,
		height = height,
		style = "minimal",
		border = "rounded",
	}
	vim.api.nvim_open_win(term_buf, true, opts)
    setup_preview_buffer(term_buf, "close")
	run_glow(term_buf, filepath)
end

-- Create 3 separate commands
vim.api.nvim_create_user_command("MarkdownPreviewSplit", M.preview_split, {})
vim.api.nvim_create_user_command("MarkdownPreviewTab", M.preview_tab, {})
vim.api.nvim_create_user_command("MarkdownPreviewPopup", M.preview_popup, {})

return M
