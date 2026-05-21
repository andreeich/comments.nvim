local M = {}

local function link_default(group, fallback)
	if next(vim.api.nvim_get_hl(0, { name = group })) then
		return
	end
	vim.api.nvim_set_hl(0, group, { link = fallback, default = true })
end

function M.setup()
	link_default("CommentBody", "DiagnosticUnderlineInfo")
end

return M
