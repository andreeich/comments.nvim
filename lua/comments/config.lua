local M = {}

M.defaults = {
	auto_enable = true,
}

M.values = vim.deepcopy(M.defaults)

function M.setup(user)
	M.values = vim.tbl_deep_extend("force", {}, M.defaults, user or {})
	return M.values
end

return M
