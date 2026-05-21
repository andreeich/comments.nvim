local render = require("comments.render")
local storage = require("comments.storage")
local ui = require("comments.ui")

local M = {}

local buffer_state = {}

local function get_buffer_state(bufnr)
	if not buffer_state[bufnr] then
		buffer_state[bufnr] = { entries = {} }
	end
	return buffer_state[bufnr]
end

local function uuid()
	math.randomseed(os.time() + (vim.uv.hrtime() % 1e6))
	local template = "xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx"
	return (
		string.gsub(template, "[xy]", function(c)
			local v = (c == "x") and math.random(0, 15) or math.random(8, 11)
			return string.format("%x", v)
		end)
	)
end

local function timestamp()
	return os.date("!%Y-%m-%dT%H:%M:%SZ")
end

local function context_for(bufnr)
	local abs = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(bufnr), ":p")
	local root = storage.root()
	local relpath = storage.relpath(root, abs)
	return root, relpath
end

local function line_text_at(bufnr, line)
	local lines = vim.api.nvim_buf_get_lines(bufnr, line - 1, line, false)
	return lines[1] or ""
end

local function find_line_by_text(bufnr, snippet)
	if not snippet or snippet == "" then
		return nil
	end
	local total = vim.api.nvim_buf_line_count(bufnr)
	for i = 0, total - 1 do
		local line = vim.api.nvim_buf_get_lines(bufnr, i, i + 1, false)[1]
		if line == snippet then
			return i + 1
		end
	end
	return nil
end

local function resolve_line(bufnr, comment)
	return find_line_by_text(bufnr, comment.line_text) or comment.line
end

function M.reload(bufnr)
	bufnr = bufnr or vim.api.nvim_get_current_buf()
	local root, relpath = context_for(bufnr)
	render.clear(bufnr)
	local bs = get_buffer_state(bufnr)
	bs.entries = {}
	if not root or not relpath then
		return
	end
	local data = storage.load(root)
	for _, c in ipairs(data.comments) do
		if c.relpath == relpath then
			local line = resolve_line(bufnr, c)
			local extmark_id = render.place(bufnr, line, c.text)
			bs.entries[#bs.entries + 1] = { id = c.id, extmark_id = extmark_id }
		end
	end
end

function M.persist(bufnr)
	bufnr = bufnr or vim.api.nvim_get_current_buf()
	local root, relpath = context_for(bufnr)
	if not root or not relpath then
		return
	end
	local bs = get_buffer_state(bufnr)
	local data = storage.load(root)
	local by_id = {}
	for _, entry in ipairs(bs.entries) do
		local current = render.current_line(bufnr, entry.extmark_id)
		if current then
			by_id[entry.id] = current
		end
	end
	for _, c in ipairs(data.comments) do
		if c.relpath == relpath and by_id[c.id] then
			c.line = by_id[c.id]
			c.line_text = line_text_at(bufnr, c.line)
		end
	end
	storage.save(root, data)
end

local function entry_at_line(bufnr, line)
	local bs = get_buffer_state(bufnr)
	for i, entry in ipairs(bs.entries) do
		if render.current_line(bufnr, entry.extmark_id) == line then
			return entry, i
		end
	end
	return nil
end

local function comment_text(data, id)
	for _, c in ipairs(data.comments) do
		if c.id == id then
			return c.text
		end
	end
	return nil
end

local function delete_comment(bufnr, root, relpath, entry, index)
	local bs = get_buffer_state(bufnr)
	pcall(vim.api.nvim_buf_del_extmark, bufnr, render.namespace(), entry.extmark_id)
	table.remove(bs.entries, index)
	local data = storage.load(root)
	local kept = {}
	for _, c in ipairs(data.comments) do
		if not (c.relpath == relpath and c.id == entry.id) then
			kept[#kept + 1] = c
		end
	end
	data.comments = kept
	storage.save(root, data)
end

local function update_comment(bufnr, root, relpath, entry, new_text)
	pcall(vim.api.nvim_buf_del_extmark, bufnr, render.namespace(), entry.extmark_id)
	local line = vim.api.nvim_win_get_cursor(0)[1]
	entry.extmark_id = render.place(bufnr, line, new_text)
	local data = storage.load(root)
	for _, c in ipairs(data.comments) do
		if c.relpath == relpath and c.id == entry.id then
			c.text = new_text
			c.line = line
			c.line_text = line_text_at(bufnr, line)
		end
	end
	storage.save(root, data)
end

local function create_comment(bufnr, root, relpath, line, text)
	local data = storage.load(root)
	local id = uuid()
	data.comments[#data.comments + 1] = {
		id = id,
		relpath = relpath,
		line = line,
		line_text = line_text_at(bufnr, line),
		text = text,
		created_at = timestamp(),
	}
	local ok, err = storage.save(root, data)
	if not ok then
		vim.notify("comments.nvim:save failed: " .. (err or "?"), vim.log.levels.ERROR)
		return
	end
	local extmark_id = render.place(bufnr, line, text)
	local bs = get_buffer_state(bufnr)
	bs.entries[#bs.entries + 1] = { id = id, extmark_id = extmark_id }
end

function M.add(bufnr)
	bufnr = bufnr or vim.api.nvim_get_current_buf()
	local root, relpath = context_for(bufnr)
	if not root then
		vim.notify("comments.nvim:no working directory", vim.log.levels.WARN)
		return
	end
	if not relpath then
		vim.notify("comments.nvim:buffer is outside the working directory", vim.log.levels.WARN)
		return
	end
	local line = vim.api.nvim_win_get_cursor(0)[1]
	local existing, index = entry_at_line(bufnr, line)
	local default = existing and comment_text(storage.load(root), existing.id) or nil
	ui.prompt(default, function(text)
		if existing then
			if text == "" then
				delete_comment(bufnr, root, relpath, existing, index)
			else
				update_comment(bufnr, root, relpath, existing, text)
			end
		elseif text ~= "" then
			create_comment(bufnr, root, relpath, line, text)
		end
	end)
end

function M.clear(bufnr)
	bufnr = bufnr or vim.api.nvim_get_current_buf()
	local root, relpath = context_for(bufnr)
	if not root or not relpath then
		return
	end
	render.clear(bufnr)
	local bs = get_buffer_state(bufnr)
	bs.entries = {}
	local data = storage.load(root)
	local kept = {}
	for _, c in ipairs(data.comments) do
		if c.relpath ~= relpath then
			kept[#kept + 1] = c
		end
	end
	data.comments = kept
	storage.save(root, data)
end

function M.render_for(bufnr, relpath)
	bufnr = bufnr or vim.api.nvim_get_current_buf()
	render.clear(bufnr)
	local root = storage.root()
	if not root or not relpath then
		return
	end
	local data = storage.load(root)
	for _, c in ipairs(data.comments) do
		if c.relpath == relpath then
			local line = resolve_line(bufnr, c)
			render.place(bufnr, line, c.text)
		end
	end
end

function M.list()
	local root = storage.root()
	if not root then
		return {}
	end
	return storage.load(root).comments
end

function M.attach(bufnr)
	bufnr = bufnr or vim.api.nvim_get_current_buf()
	local state = require("comments.state")
	local group = vim.api.nvim_create_augroup("comments.nvim." .. bufnr, { clear = true })
	vim.api.nvim_create_autocmd("BufWritePost", {
		group = group,
		buffer = bufnr,
		callback = function()
			M.persist(bufnr)
		end,
	})
	state.get(bufnr).enabled = true
	M.reload(bufnr)
end

function M.detach(bufnr)
	bufnr = bufnr or vim.api.nvim_get_current_buf()
	local state = require("comments.state")
	pcall(vim.api.nvim_del_augroup_by_name, "comments.nvim." .. bufnr)
	render.clear(bufnr)
	buffer_state[bufnr] = nil
	state.clear(bufnr)
end

return M
