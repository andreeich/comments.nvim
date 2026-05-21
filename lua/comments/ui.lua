local M = {}

function M.prompt(default, on_submit)
	vim.ui.input({ prompt = "Comment: ", default = default or "" }, function(input)
		if input == nil then
			return
		end
		on_submit(input)
	end)
end

return M
