---
-- Efuns - (Game) Engine functions
--
-- A collection of functions that are used to build the actual game.
--

-- Keep a local pointer to potentially insecure functions that we still need
-- to operate the game.
local l_loadfile = loadfile -- add a pointer to loadfile in our local scope.

local game_objects = {}  -- stores all game objects
local class_def = {}     -- stores loaded class definitions.

---
-- We keep track of the number of clones we've created
-- so we can make sure that each clone gets a unique id.
--
local object_counter = {}

efun = {} -- namespace...

function efun:dump_objects()
	for base, t in pairs(game_objects) do
		print(base)
		if t then
			for ref, o in pairs(game_objects[base]) do
				print("  " .. ref .. (o and "  {...}" or "  nil") )
			end
		else
			print("nil")
		end
	end
end

function efun:load_object(ref)
	local file = ref_to_filename(ref)
	local env = setmetatable({}, { __index = _G })
	
	assert(pcall(setfenv(assert(l_loadfile(file)), env)))

	local base = nil
	if nil ~= env.inherit then
		base = env.inherit
		if nil == class_def[base] then
			dprint("loading parent ", base)
			efun:load_object(base)
		end
	end
	
	if nil ~= base then
		base = class_def[base]
	end

	class_def[ref] = class(base, env)
	return class_def[ref]
end

function efun:clone_object(ref, config)
	if nil == config then
		config = {}
	end

	if nil == class_def[ref] then
		dprint('Loading class ', ref)
		efun:load_object(ref)
	end
	
	local clones = nil
	if nil == game_objects[ref] then
		game_objects[ref] = {}
		clones = game_objects[ref]
		object_counter[ref] = 1
	else
		clones = game_objects[ref]
		object_counter[ref] = object_counter[ref] + 1
	end

	config.id = ref .. '#' .. tostring(object_counter[ref])
	local obj = class_def[ref]:create(config)

	clones[obj.id] = obj
	dprint('Cloned object ', obj.id)
	
	return obj
end

function efun:find_object(ref)
	local base, id = ref:match("([^#]+)#?(%d*)")

	if nil == game_objects[base] then
		dprint("No objects of type ", base)
		return nil
	end

	local clones = game_objects[base]
	-- TODO perhaps we should only use the numeric part
	-- as key in clones.
	if nil == id or "" == id then
		local _, clone = next(clones) -- Just grab the first one.
		return clone
	end
	
	if nil ~= clones[ref] then
		return clones[ref] -- found a match
	end

	dprint("Could not find object ", ref)
	return nil
end

---
-- Find an object(query) in another(env)
-- where query can either be a descriptive string
-- eg 'rock' or an object.
--
-- The first matching object will be returned unless
-- the query also contains a number eg 'rock 2'
-- in that case the n:th match will be returned.
--
-- If the third parameter is specified and the query does
-- not contain a number then all matches will be returned.
--
-- If query is an object that object will be returned
-- if it's in the inventory.
--
function efun:in_inv(obj, env, return_all)
	local inv = env:getInventory()

	if efun:is_object(obj) then
		if inv[obj.id] then
			return obj
		end
		return nil
	end

	-- Match 'sword', 'sword 2', 'black sword 2'
	local str, num = obj:match("^(%a[%s%a]*%a)%s-(%d*)$")
	num = tonumber(num)
	if not num and not return_all then num = 1 end
	str = str:gsub("%s+", " ") -- Remove duplicate spaces.

	local i, matches = 1, {}
	for _,o in pairs(inv) do
		if o:id_as(str) then -- id_as() must exist in all objects
			if num then
				if i == num then return o end
				i = i + 1
			else
				table.insert(matches, o)
			end
		end
	end

	if return_all and not table.empty(matches) then
		if table.sizeof(matches) == 1 then
			return matches[1]
		end
		return matches
	end

	return nil -- couldn't find the object
end

function efun:is_object(obj)
	if type(obj) == 'table' then
		if obj.__gameObject then
			return true
		end
	end

	return false
end

function efun:move_object(obj, dest)
	if obj == dest then
		dprint("move_object: obj and dest are the same, aborting.")
		return false
	end
	
	local env = obj:getEnv()
	if nil ~= env then
		if env == dest then
			return false
		end
		env:removeInventory(obj) -- should trigger leave_inv
	end

	dprint(string.format("Moving %s to %s.", obj.id, dest.id))
	obj:setEnv(dest)
	dest:addInventory(obj) -- this should trigger enter_inv
end

---
-- Livings (players / monsters) can perform actions.
-- An action is a function that can be assigned to a Living by
-- any other game object, using add_action().

-- The rules are simple:
--   For an action to be considered valid the object responsible needs to
--   be near the Living (in env or inventory).
--
--   Action functions must return true if it was able to execute and false
--   otherwise. This is so we know if we should pass the input to another
--   action.

function efun:add_action(obj, func, triggers)
	if nil == obj.actions then
		obj.actions = {}
	end
	
	for _,trigger in ipairs(triggers) do
		obj.actions[trigger] = func
	end
end

function efun:call_action(ch, cmd, args)

	local call = function(obj)
		local actions = efun:get_actions(obj) -- Get list of livings actions
		if nil ~= actions[cmd] then
			local f = obj[actions[cmd]]
			if type(f) == 'function' then --extra sanity check
				--- called with
				-- object function is declared in
				-- The living performing the action
				-- A list of arguments if any were given.
				ch.last_cmd = {cmd, args}
				return f(obj, ch, args)
			end
		end
	end

	local env = ch:getEnv()
	if nil ~= env and call(env) then
		return true
	end

	if call(ch) then
		return true
	end

	send("What?\n")
	return false
end

---
-- TODO if object has an inventory then destroy that as well.
-- ie if a room has 3 objects and the room is destroyed, the objects should be
-- destroyed as well. The only exception is players, they should be transfered
-- somewhere else.
--
function efun:destroy_object(obj)
	local env = obj:getEnv()
	if env then
		env:removeInventory(obj)
	end

	local inv = obj:getInventory()
	for _, o in pairs(inv) do
		if efun:is_player(o) then
			pcall(player_env_destructed, o, obj.id)
		else
			efun:destroy_object(o)
		end
	end

	local ref = obj.id
	local base, id = ref:match("([^#]+)#?(%d*)")

	if nil == game_objects[base] then
		return
	end

	local clones = game_objects[base]
	if nil ~= clones[ref] then
		clones[ref] = nil
	end
end

function efun:get_actions(obj)
	return obj.actions
end

function efun:is_player(obj)
	if not obj.client or type(obj.client) ~= 'table' then
		return false
	end

	if not obj.client.socket or not obj.client.socket:getpeername() then
		return false
	end

	return true
end

local is_shutdown_in_progress = false
function efun:shutdown_in_progress()
	return is_shutdown_in_progress
end

function efun:shutdown()
	Net:shutdown() -- Stop listening for new connections
	
	for _, client in pairs(Net.sockets) do
		Net:send(client, "Game is shutting down...\nGood bye!\n")
		Net:disconnect(client)
	end

	is_shutdown_in_progress = true
end

---
-- Will find all livings in env and send str to them.
-- If exclude is specified that object will be excluded.
function efun:tell_env(env, str, exclude)
	if nil == env then
		return -- raise error?
	end

	local objects = env:getInventory()
	for _,o in pairs(objects) do
		if efun:is_player(o) then
			if nil == exclude or o.id ~= exclude.id then
				Net:send(o.client, str)
			end
		else
			-- TODO allow objects to listen to this using a
			-- method like catch_tell. This can lead to interesting
			-- interactions between players and objects/npcs.
		end
	end
end
