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
	local clients = vim.lsp.get_clients({ bufnr = 0 }) or {}
	local tried = 0
	local found = false

	if #clients == 0 then
		vim.notify("No LSP clients attached to this buffer.", vim.log.levels.WARN)
		return
	end

	for _, client in ipairs(clients) do
		if client.supports_method("textDocument/hover") then
			local encoding = client.offset_encoding or "utf-16"
			local params = vim.lsp.util.make_position_params(0, encoding)

			vim.lsp.buf_request(client.id, "textDocument/hover", params, function(err, result)
				tried = tried + 1

				if not found and result and result.contents then
					local lines = vim.lsp.util.convert_input_to_markdown_lines(result.contents)
					lines = vim.split(table.concat(lines, "\n"), "\n", { trimempty = true })

					if not vim.tbl_isempty(lines) then
						found = true -- suppress further attempts or warnings

						-- Save to temp file
						local tmpfile = vim.fn.tempname() .. ".md"
						local fd = assert(io.open(tmpfile, "w"))
						fd:write(table.concat(lines, "\n"))
						fd:close()

						M.preview_popup_file(tmpfile)
					end
				end

				-- All clients tried and still nothing → show warning once
				if tried == #clients and not found then
					vim.notify("No hover content available from any LSP.", vim.log.levels.INFO)
				end
			end)
		else
			tried = tried + 1
		end
	end
end

-- Create 3 separate commands
vim.api.nvim_create_user_command("MarkdownPreviewSplit", M.preview_split, {})
vim.api.nvim_create_user_command("MarkdownPreviewTab", M.preview_tab, {})
vim.api.nvim_create_user_command("MarkdownPreviewPopup", M.preview_popup, {})

vim.api.nvim_create_user_command("DocumentationPreview", function()
	M.preview_hover_doc()
end, { desc = "Preview LSP hover content in glow" })

return M
