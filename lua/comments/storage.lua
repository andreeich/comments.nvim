local M = {}

local function path_join(...)
	return table.concat({ ... }, "/")
end

local function exists(path)
	return vim.uv.fs_stat(path) ~= nil
end

function M.root()
	return vim.fn.fnamemodify(vim.fn.getcwd(), ":p"):gsub("/$", "")
end

function M.relpath(root, abs_path)
	if not root or not abs_path or abs_path == "" then
		return nil
	end
	local prefix = root .. "/"
	if abs_path:sub(1, #prefix) == prefix then
		return abs_path:sub(#prefix + 1)
	end
	return nil
end

function M.json_path(root)
	return path_join(root, ".comments", "comments.json")
end

function M.load(root)
	if not root then
		return { version = 1, comments = {} }
	end
	local path = M.json_path(root)
	if not exists(path) then
		return { version = 1, comments = {} }
	end
	local fd = assert(io.open(path, "r"))
	local raw = fd:read("*a")
	fd:close()
	local ok, decoded = pcall(vim.json.decode, raw)
	if not ok or type(decoded) ~= "table" then
		return { version = 1, comments = {} }
	end
	decoded.version = decoded.version or 1
	decoded.comments = decoded.comments or {}
	return decoded
end

function M.save(root, data)
	if not root then
		return false, "no cwd"
	end
	local dir = path_join(root, ".comments")
	vim.fn.mkdir(dir, "p")
	local path = M.json_path(root)
	local encoded = vim.json.encode(data)
	local fd, err = io.open(path, "w")
	if not fd then
		return false, err
	end
	fd:write(encoded)
	fd:close()
	return true
end

return M
