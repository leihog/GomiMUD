inherit = "/std/object"

name = "Player"
cap_name = "Player"
title = "the Adventurer"
client = nil -- Stores the client (socket info, input handler etc) object

__init = function(self)
	parent.__init(self)

	-- second param is the function name
	-- third param is the triggers.
	efun:add_action(self, 'act_look', {'look', 'l'})
	efun:add_action(self, 'act_quit', {'quit'})
	efun:add_action(self, 'act_shutdown', {'shutdown'})
	efun:add_action(self, 'act_say', {'say'})
	efun:add_action(self, 'act_save', {'save'})
	efun:add_action(self, 'act_take', {'take', 'pick'})
	efun:add_action(self, 'act_who', {'who'})
	efun:add_action(self, 'act_drop', {'drop'})
	efun:add_action(self, 'act_inventory', {'inventory', 'i'})
	efun:add_action(self, 'act_dump', {'dump'})
end

function act_dump(self, ch, args)
	efun:dump_objects()
end

function short(self)
	return self.cap_name ..' '.. self.title
end

function long(self)
	return self:short() .. "\nThis should contain an interesting description..."
end

function act_save(self, ch, args)
	save_player(ch)
	send("saved.\n")
	return true
end

function move(self, dest, dir)
	local env  = self:getEnv()
	local room = efun:find_object(dest)
	if nil == room then
		room = efun:clone_object(dest)
	end

	-- tell the room that we are leaving...
	if env and env.light > 0 then
		efun:tell_env(env, self.cap_name .. " leaves " .. dir .. "\n", self)
	end

	efun:move_object(self, room)

	efun:call_action(self, 'look') -- take a look around...
	-- tell the room that we arrived.
	if room.light > 0 then
		efun:tell_env(room, self.cap_name .. " arrives\n", self)
	end
end

function act_look(self, ch, args)
	local env = ch:getEnv()

	if not args or args == '' then
		if env.light == 0 then
			send("[A dark room]\n")
			send("It is dark\n")
			return
		end

		send("[" .. env:short() .. "]\n")
		send(env:long() .. "\n")

		local c = table.sizeof(env.exits)
		if c > 0 then
			send("    Obvious exits: ")
			local i = 0;
			for dir,file in pairs(env.exits) do
				i = i + 1
				send(dir)
				if i == c then
					send("\n")
				elseif i == (c - 1) then
					send(" and ")
				else
					send(", ")
				end
			end
		else
			send("No obvious exits.\n")
		end

		-- List objects in the env
		local inv = env:getInventory()
		for id, obj in pairs(inv) do
			if self ~= obj then
				send(obj:short() .. "\n")
			end
		end
		return true
	end
	
	local item = args:match("^at (%a[%s%w]+)$")
	if not item then item = args:match("^in (%a[%s%w]+)$") end

	if item == '' then
		send("What do you want to look at?\n")
		return true
	end

	if env.light == 0 then
		send("It is to dark to see.\n")
	end

	local obj = efun:in_inv(item, env, 1)
	if not obj then
		send("There is no such thing.\n")
		return true
	end

	if not efun:is_object(obj) then
		-- We assume that it's an array of objects...
		send("Which item did you want to look at?\n")
		for _,o in pairs(obj) do
			send("  " .. o:short() .. "\n")
		end
		return true
	end

	send(obj:long() .. "\n")
	-- TODO show inventory?

	-- TODO allow items in an inventory to add distinguished
	--      features to it's host. Ex: a large sword carried by a player
	--      would show when you look at the player even tho the sword is not
	--      currently in use (wielded).

	return true
end

---
-- TODO Might want to add support for syntax: 'pick up stone'
--
function act_take(self, ch, args)
	
	local item
	local cmd, _ = unpack( ch.last_cmd )
	if cmd == 'pick' and args:sub(1,2) ~= 'up' then
		return false -- User is not trying to pick up something
	end
	
	if not empty(args) then
		if cmd == 'pick' then
			item = args:match("^up (%a[%s%w]+)$")
		else
			item = args
		end
	end

	if empty(item) then
		send("What do you want to take?\n")
		return true
	end

	local env = ch:getEnv()
	local obj = efun:in_inv(item, env, 1)
	if not obj then
		send("There is no such thing here.\n")
		return true
	end

	if not efun:is_object(obj) then
		-- We assume that it's an array of objects...
		send("Which item did you want to take?\n")
		for _,o in pairs(obj) do
			send("  " .. o:short() .. "\n")
		end
		return true
	end

	efun:move_object(obj, ch) -- Move item to players inventory
	local short = string.lower(obj:short())
	send("You put ".. short .. " in your inventory.\n")
	efun:tell_env(env, ch.cap_name .. " takes " .. short .. "\n", ch)
	return true
end

function act_drop(self, ch, args)

	if empty(args) then
		send("What do you want to drop?\n")
		return true
	end

	local env = ch:getEnv()
	local obj = efun:in_inv(args, ch, 1)
	if not obj then
		send("You don't have that.\n")
		return true
	end

	if not efun:is_object(obj) then
		-- We assume that it's an array of objects...
		send("Which item did you want to drop?\n")
		for _,o in pairs(obj) do
			send("  " .. o:short() .. "\n")
		end
		return true
	end

	efun:move_object(obj, env) -- Move item to players environment
	local short = string.lower(obj:short())
	send("You drop ".. short .. ".\n")
	efun:tell_env(env, ch.cap_name .. " drops " .. short .. ".\n", ch)
	return true
end

function act_inventory(self, ch, args)
	
	local inv = ch:getInventory()
	if empty(inv) then --TODO when we have 'hidden' objects this wont work.
		send("You aren't carrying anything.\n")
		return true
	end

	send("You are carrying:\n")
	for _,o in pairs(inv) do
		send("  " .. o:short() .. "\n")
	end

	return true
end

function act_say(self, ch, str)
	send("You say: ".. str .."\n")
	efun:tell_env(self:getEnv(), self.name .." says: ".. str .. "\n", self)
	return true
end

function act_shutdown(self, ch, args)
	efun:shutdown()
	return true
end

function act_who(self, ch, args)
	local online = online_players()
	local c = table.sizeof(online)

	send("Online players:\n")
	for _, p in pairs(online) do
		send("  " .. p:short() .. "\n")
	end

	send(string.format(
		"%s player%s online.\n",
		c, (c ~= 1 and 's' or '')
	))

	return true
end

function act_quit(self, ch, args)
	disconnect_player(self)
	return true
end
