local M = {}

local NS = vim.api.nvim_create_namespace("comments")
local PRIORITY = 18

function M.namespace()
	return NS
end

function M.clear(bufnr)
	vim.api.nvim_buf_clear_namespace(bufnr, NS, 0, -1)
end

local function preview(text)
	local first = (text or ""):match("[^\n]*") or ""
	local has_more = (text or ""):find("\n", 1, true) ~= nil
	return "󰭹 " .. first .. (has_more and " …" or "")
end

function M.place(bufnr, line, text)
	if line < 1 then
		line = 1
	end
	local lcount = vim.api.nvim_buf_line_count(bufnr)
	if line > lcount then
		line = lcount
	end
	return vim.api.nvim_buf_set_extmark(bufnr, NS, line - 1, 0, {
		virt_text = { { preview(text), "CommentBody" } },
		virt_text_pos = "eol",
		priority = PRIORITY,
	})
end

function M.current_line(bufnr, extmark_id)
	local pos = vim.api.nvim_buf_get_extmark_by_id(bufnr, NS, extmark_id, {})
	if not pos or #pos == 0 then
		return nil
	end
	return pos[1] + 1
end

return M
