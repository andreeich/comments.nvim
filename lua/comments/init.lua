local core = require("comments.core")
local config = require("comments.config")
local highlights = require("comments.highlights")
local state = require("comments.state")

local M = {
	_did_setup = false,
	_auto_group = nil,
}

local function current_buf()
	return vim.api.nvim_get_current_buf()
end

local function user_command(name, rhs, opts)
	vim.api.nvim_create_user_command(name, rhs, opts or {})
end

local function configure_auto_enable(initial)
	if M._auto_group then
		pcall(vim.api.nvim_del_augroup_by_id, M._auto_group)
		M._auto_group = nil
	end

	if not config.values.auto_enable then
		return
	end

	M._auto_group = vim.api.nvim_create_augroup("comments.nvim.auto", { clear = true })
	vim.api.nvim_create_autocmd("BufEnter", {
		group = M._auto_group,
		callback = function(args)
			vim.schedule(function()
				if vim.api.nvim_buf_is_valid(args.buf) and not state.get(args.buf).enabled then
					core.attach(args.buf)
				end
			end)
		end,
	})

	if initial then
		vim.schedule(function()
			local bufnr = vim.api.nvim_get_current_buf()
			if vim.api.nvim_buf_is_valid(bufnr) and not state.get(bufnr).enabled then
				core.attach(bufnr)
			end
		end)
	end
end

function M.setup(opts)
	config.setup(opts)
	highlights.setup()
	configure_auto_enable(not M._did_setup)

	if M._did_setup then
		return
	end
	M._did_setup = true

	user_command("CommentAdd", function()
		core.add(current_buf())
	end, {})
	user_command("CommentRemove", function(opts)
		core.remove({
			bufnr = current_buf(),
			line1 = opts.range > 0 and opts.line1 or nil,
			line2 = opts.range > 0 and opts.line2 or nil,
		})
	end, { range = true })
	user_command("CommentClear", function()
		core.clear(current_buf())
	end, {})
	user_command("CommentPreview", function()
		core.preview(current_buf())
	end, {})
end

M.attach = function(bufnr)
	core.attach(bufnr or current_buf())
end
M.detach = function(bufnr)
	core.detach(bufnr or current_buf())
end
M.comment = function()
	core.add(current_buf())
end
M.comment_remove = function(opts)
	core.remove(vim.tbl_extend("force", { bufnr = current_buf() }, opts or {}))
end
M.comment_clear = function()
	core.clear(current_buf())
end
M.comment_preview = function()
	core.preview(current_buf())
end
M.comment_list = function()
	return core.list()
end
M.render_for = function(bufnr, relpath)
	core.render_for(bufnr, relpath)
end

return M
