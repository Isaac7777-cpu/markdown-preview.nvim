local M = {}

M.version = "0.1.0-alpha"

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

-- Get terminal capability (terminfo) via tput, with fallback
local function termcap(names, fallback)
	for _, name in ipairs(type(names) == "table" and names or { names }) do
		local out = vim.fn.system({ "tput", "-T", vim.env.TERM or "", name })
		if vim.v.shell_error == 0 and type(out) == "string" and #out > 0 then
			out = out:gsub("\r", ""):gsub("\n", "")
			if #out > 0 then
				return out
			end
		end
	end
	return fallback
end

local ESC = string.char(27)
local KEY = {
	LEFT = termcap({ "kcub1", "kLFT" }, ESC .. "[D"),
	RIGHT = termcap({ "kcuf1", "kRIT" }, ESC .. "[C"),
	UP = termcap({ "kcuu1", "kUP" }, ESC .. "[A"),
	DOWN = termcap({ "kcud1", "kDN" }, ESC .. "[B"),
	PAGEUP = termcap("kpp", ESC .. "[5~"),
	PAGEDOWN = termcap("knp", ESC .. "[6~"),
}

-- Only send to the pager if the cursor is on the visible window edge
local function map_normal_passthrough_guarded(term_buf, job_id)
	local function at_top()
		return vim.api.nvim_win_get_cursor(0)[1] == vim.fn.line("w0")
	end
	local function at_bottom()
		return vim.api.nvim_win_get_cursor(0)[1] == vim.fn.line("w$")
	end
	local function at_left()
		return vim.fn.virtcol(".") == 1
	end
	local function at_right()
		return vim.fn.virtcol(".") >= vim.api.nvim_win_get_width(0)
	end

	local function expr_send(pred, bytes, fallback_keys)
		return function()
			if pred() then
				vim.fn.jobsend(job_id, bytes)
				return ""
			end
			return fallback_keys
		end
	end

	local o = { buffer = term_buf, noremap = true, silent = true, nowait = true, expr = true }

	-- vertical motion
	vim.keymap.set("n", "j", expr_send(at_bottom, "j", "j"), o)
	vim.keymap.set("n", "k", expr_send(at_top, "k", "k"), o)
	vim.keymap.set("n", "<Down>", expr_send(at_bottom, KEY.DOWN, "<Down>"), o)
	vim.keymap.set("n", "<Up>", expr_send(at_top, KEY.UP, "<Up>"), o)

	-- horizontal pan
	vim.keymap.set("n", "h", expr_send(at_left, KEY.LEFT, "h"), o)
	vim.keymap.set("n", "l", expr_send(at_right, KEY.RIGHT, "l"), o)
	vim.keymap.set("n", "<Left>", expr_send(at_left, KEY.LEFT, "<Left>"), o)
	vim.keymap.set("n", "<Right>", expr_send(at_right, KEY.RIGHT, "<Right>"), o)

	-- page/half-page (only when at vertical borders)
	vim.keymap.set("n", "<PageDown>", expr_send(at_bottom, KEY.PAGEDOWN, "<PageDown>"), o)
	vim.keymap.set("n", "<PageUp>", expr_send(at_top, KEY.PAGEUP, "<PageUp>"), o)
	vim.keymap.set("n", "<C-d>", expr_send(at_bottom, "\004", "<C-d>"), o) -- ^D
	vim.keymap.set("n", "<C-u>", expr_send(at_top, "\025", "<C-u>"), o) -- ^U
end

-- Core terminal previewer
local function run_glow(term_buf, filepath)
	vim.api.nvim_buf_set_option(term_buf, "filetype", "")
	pcall(vim.treesitter.stop, term_buf)
	vim.bo[term_buf].scrollback = 100000 -- keep lots of history

	-- -p: use pager, defaults to less if $PAGER unset
	-- -w 1200: prevent glow from re-wrapping to a narrow width
	local cmd = { "glow", "-p", "-w", "0", filepath }

	local job_id = vim.fn.termopen(cmd, {
		env = { PAGER = "less -RS" }, -- R: keep colors, S: chop (h-scroll with ←/→)
		on_exit = function(_, code)
			if code ~= 0 then
				vim.api.nvim_err_writeln("glow exited with code " .. code)
			end
		end,
	})
	-- IMPORTANT: make sure the numbers/signs aren’t stealing columns
	local win = vim.api.nvim_get_current_win()
	vim.wo[win].number = false
	vim.wo[win].relativenumber = false
	vim.wo[win].signcolumn = "no"
	vim.wo[win].foldcolumn = "0"

	map_normal_passthrough_guarded(term_buf, job_id)
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

function M.preview_popup_file(filepath)
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

-- Popup preview
function M.preview_popup()
	local filepath = write_tempfile()
	M.preview_popup_file(filepath)
end

function M.preview_hover_doc()
	local client = vim.lsp.get_clients({ bufnr = 0 })[1]
	local encoding = client and client.offset_encoding or "utf-16"
	local params = vim.lsp.util.make_position_params(0, encoding)

	vim.lsp.buf_request_all(0, "textDocument/hover", params, function(results)
		for client_id, res in pairs(results) do
			local result = res.result
			if result and result.contents then
				local lines = vim.lsp.util.convert_input_to_markdown_lines(result.contents)
				lines = vim.split(table.concat(lines, "\n"), "\n", { trimempty = true })

				-- fallback if markdown_lines is empty
				if vim.tbl_isempty(lines) and type(result.contents) == "table" and result.contents.value then
					lines = vim.split(result.contents.value, "\n", { trimempty = true })
				end

				if not vim.tbl_isempty(lines) then
					local tmpfile = vim.fn.tempname() .. ".md"
					local fd = assert(io.open(tmpfile, "w"))
					fd:write(table.concat(lines, "\n"))
					fd:close()

					M.preview_popup_file(tmpfile)
					return
				end
			end
		end

		vim.notify("No hover content available from any LSP.", vim.log.levels.INFO)
	end)
end

-- Create 3 separate commands
vim.api.nvim_create_user_command("MarkdownPreviewSplit", M.preview_split, {})
vim.api.nvim_create_user_command("MarkdownPreviewTab", M.preview_tab, {})
vim.api.nvim_create_user_command("MarkdownPreviewPopup", M.preview_popup, {})

vim.api.nvim_create_user_command("DocumentationPreview", function()
	M.preview_hover_doc()
end, { desc = "Preview LSP hover content in glow" })

return M
