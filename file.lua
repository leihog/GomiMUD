---
-- Limit File IO to lib folder
--
local function safe_path(filepath)
	return './lib' .. filepath
end

File = {}

function File:get(filename)
	return File:get_contents(filename)
end

function File:get_contents(filename)
	filename = safe_path(filename)

	local f = assert(io.open(filename, "r"))
	local content = f:read("*all")
	f:close()

	return content
end

function File:put(filename, contents)
	return File:put_contents(filename, contents)
end

function File:put_contents(filename, contents)
	filename = safe_path(filename)

	local f = assert(io.open(filename, "w+"))
	f:write(contents)
	f:close ()
end

function File:open(filename, mode)
	filename = safe_path(filename)
	local f = assert(io.open(filename, mode))
	return f
end

function File:exists(filename)
	local f = io.open(safe_path(filename), "r")
	if f ~= nil then
		io.close(f)
		return true
	end

	return false
end

