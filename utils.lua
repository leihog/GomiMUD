
---
-- Utility functions
--

function capitalize(str)
	return string.upper(string.sub(str, 1, 1)) ..
		string.lower(string.sub(str, 2))
end

function cat(client, filename)
	local f = File:open(filename, "r")
	for l in f:lines() do
		Net:send(client, l .. "\n")
	end
	f:close()
end

function dprint(...)
	if not(DEBUG) then return end
	return print(unpack(arg))
end

function getObjectProperties(t, prevData)
	-- if prevData == nil, start empty, otherwise start with prevData
	local data = prevData or {}

	-- copy all the attributes from t
	for k,v in pairs(t) do
		if nil == data[k] and type(v) ~= 'function' then
			data[k] = v
		end
	end

	-- get t's metatable, or exit if not existing
	local mt = getmetatable(t)
	if type(mt)~='table' then return data end

	-- get the __index from mt, or exit if not table
	local index = mt.__index
	if type(index)~='table' then return data end
	if index == _G then return data end

	-- include the data from index into data, recursively, and return
	return getObjectProperties(index, data)
end

---
-- Test if o is empty
function empty(o)
	if o == nil then return true end
	if type(o) == 'string' and o == '' then return true end
	if type(o) == 'table' and not next(o) then return true end

	return false
end

function table.empty(t)
	if next(t) == nil then
		return true
	end
	return false
end

function table.sizeof(t)
	if table.empty(t) then
		return 0
	end

	local size = table.getn(t)
	if size > 0 then
		return size
	end

	for _, _ in pairs(t) do
		size = size + 1
	end

	return size
end

-- Dumps a table including metatables (__index)
function dump(obj, indent)
	local spaces = ''
	if nil == indent then
		indent = 0
	else
		spaces = string.rep(" ", indent)
	end

	if type(obj) == 'table' then
		for k,v in pairs(obj) do
			
			if type(v) == 'table' then
				print(spaces .. k ..' {')
				dump(v, (indent + 2))
				print(spaces .. '}')
			elseif type(v) == 'function' then
				print(spaces .. k ..': function')
			else
				print(spaces .. k ..': '.. v) -- display an empty value somehow...
			end
		end

		local meta, parent = getmetatable(obj), nil
		if nil ~= meta then
			parent = meta.__index
			if parent == _G then
				return
			end
			print("\nparent:---------\n")
			dump(parent)
		end
	end
end

function get_scriptname(ref)
	if type(ref) == 'table' then ref = ref.id end

	local base, id = ref:match("([^#]+)#?(%d*)")
	return base
end

---
-- Class and file functions
--

function ref_to_filename(ref)
	if ref:sub(-4) ~= '.lua' then
		ref = ref .. '.lua'
	end
	
	-- TODO perhaps there is a better way of ensuring that we don't
	-- break out of our game dir.
	ref = './lib' .. ref -- Prefix path with game obj dir
	return ref
end

function class(base_class, new_class)
	function new_class:create(def)
		setmetatable(def, { __index = new_class })
		if nil ~= def.__init then
			def:__init()
		end
		return def
	end

	if nil ~= base_class then
		new_class.parent = base_class
		setmetatable(new_class, { __index = base_class })
	else
		--setmetatable(new_class, { __index = _G })
	end

	return new_class
end
