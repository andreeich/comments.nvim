local M = {}

local buffers = {}

function M.get(bufnr)
	if bufnr == 0 then
		bufnr = vim.api.nvim_get_current_buf()
	end
	if not buffers[bufnr] then
		buffers[bufnr] = { bufnr = bufnr, enabled = false }
	end
	return buffers[bufnr]
end

function M.clear(bufnr)
	if bufnr == 0 then
		bufnr = vim.api.nvim_get_current_buf()
	end
	buffers[bufnr] = nil
end

return M
