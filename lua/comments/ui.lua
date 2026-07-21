local M = {}

local function wrapped_height(lines, width, min_height, max_height)
	local height = 0
	local content_width = math.max(width, 1)
	for _, line in ipairs(lines) do
		local display_width = math.max(vim.fn.strdisplaywidth(line), 1)
		height = height + math.max(1, math.ceil(display_width / content_width))
	end
	return math.min(math.max(height, min_height), max_height)
end

local function enable_wrap(win)
	vim.api.nvim_set_option_value("wrap", true, { win = win })
	vim.api.nvim_set_option_value("linebreak", true, { win = win })
	vim.api.nvim_set_option_value("breakindent", true, { win = win })
end

function M.prompt(default, on_submit)
	local lines = vim.split(default or "", "\n", { plain = true })
	local buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	vim.bo[buf].bufhidden = "wipe"
	vim.bo[buf].filetype = "markdown"
	local width = math.min(math.max(60, math.floor(vim.o.columns * 0.5)), 100)
	local height = wrapped_height(lines, width, 5, 15)
	local win = vim.api.nvim_open_win(buf, true, {
		relative = "cursor",
		row = 1,
		col = 0,
		width = width,
		height = height,
		style = "minimal",
		border = "rounded",
		title = " Comment (<C-s> submit, <Esc> cancel) ",
		title_pos = "left",
	})
	enable_wrap(win)
	local function close()
		if vim.api.nvim_win_is_valid(win) then
			vim.api.nvim_win_close(win, true)
		end
		vim.cmd("stopinsert")
	end
	local function submit()
		local text = table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n")
		close()
		on_submit(text)
	end
	vim.keymap.set("n", "<CR>", submit, { buffer = buf, nowait = true })
	vim.keymap.set({ "n", "i" }, "<C-s>", submit, { buffer = buf, nowait = true })
	vim.keymap.set("n", "<Esc>", close, { buffer = buf, nowait = true })
	vim.keymap.set("n", "q", close, { buffer = buf, nowait = true })
	vim.cmd("startinsert!")
end

local popup = { win = nil, buf = nil }

function M.close_popup()
	if popup.win and vim.api.nvim_win_is_valid(popup.win) then
		pcall(vim.api.nvim_win_close, popup.win, true)
	end
	if popup.buf and vim.api.nvim_buf_is_valid(popup.buf) then
		pcall(vim.api.nvim_buf_delete, popup.buf, { force = true })
	end
	popup.win = nil
	popup.buf = nil
end

function M.show_popup(text)
	M.close_popup()
	local lines = vim.split(text or "", "\n", { plain = true })
	local width = math.min(math.max(40, math.floor(vim.o.columns * 0.4)), 80)
	local height = wrapped_height(lines, width, 1, 20)
	local buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	vim.bo[buf].modifiable = false
	vim.bo[buf].bufhidden = "wipe"
	local win = vim.api.nvim_open_win(buf, false, {
		relative = "cursor",
		row = 1,
		col = 0,
		width = width,
		height = height,
		style = "minimal",
		border = "rounded",
		focusable = false,
		noautocmd = true,
	})
	enable_wrap(win)
	popup.win = win
	popup.buf = buf
end

return M
