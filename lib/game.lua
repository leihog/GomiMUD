---
-- This is the main game object (/lib/game.lua)
-- This is the only required lib file.
--


---
-- Configure the game engine
--
Game = {}
Game.port = 2000
Game.name = "GomiMUD"
Game.version = "v0.2"
Game.player_object = "/std/player"

---
-- Player objects, kept here for easy access.
local chars = {}

---
-- Called right before the game starts accepting players.
--
function Game:init()
	local preload = {
		'/std/object', '/std/player', '/std/room',
	}
	print("Preloading standard objects...")
	for _, script in ipairs(preload) do
		print("    loading ".. script)
		efun:load_object(script)
	end
	print("\n")
end

--- this_player
-- When a player triggers a chain of events, say by executing a command,
-- we store a pointer to that player in this_player. This is required by
-- the send() function that uses this_player in order to write to the
-- right socket.
--
-- TODO not sure this is entirely safe... might be overwritten or point to wrong
-- player, but seems to work for now.
local this_player = nil

---
-- Sends str to the active player
-- active player being the player that triggered the current event chain
function send(str)
	if nil == this_player then
		dprint("this_player is nil...\n")
		return
	end

	Net:send(this_player, str)
end

function send_prompt(client)
	Net:send(client, ">") -- Prompt, not very exciting.
end

---
-- Called on player input
--
function parseCommand(line, client)
	local char = client.char
	local cmd, args = line:match("(%w+)%s*(.*)")
	
	this_player = client
	efun:call_action(char, cmd, args)
	this_player = nil
	send_prompt(client)
end

---
-- called by destroy_object when a player is in a room
-- that is destructed.
--
-- old_env is the room that got destructed.
--
function player_env_destructed(ch, old_env)
	local void = efun:find_object(Game.void_location)
	if not void then
		void = efun:clone_object(Game.void_location)
	end

	efun:move_objects(ch, void)
	Net:send(ch, "The world around you starts to disintigrate.\n")
end

function online_players()
	local players = {}
	for _, c in pairs(chars) do
		if c.playing then
			table.insert(players, c)
		end
	end

	return players
end

function player_exists(name)
	if File:exists("/players/" .. name .. ".o") then
		return true
	end
	return false
end

function load_player(name)
	local data = File:get("/players/" .. name .. ".o")
	data = JSON:decode(data)
	return data
end

function save_player(ch)
	local client = ch.client
	ch.client = nil
	
	local data = deflate_object(ch)
	data.playing = nil
	
	data = JSON:encode(data)
	File:put("/players/" .. ch.name .. ".o", data)

	ch.client = client
end

function restore_object(data)

	local base, id = string.match(data.id, "([^#]+)#?(%d*)")
	local obj = efun:clone_object(base)

	for k,v in pairs(data) do
		if k == 'inventory' then
			for _, invobj in ipairs(v) do
				invobj = restore_object(invobj)
				efun:move_object(invobj, obj);
			end
		elseif k == 'environment' then
			-- we don't want to restore the env for now.
		elseif k == 'id' then
			-- we don't want to overwrite the id.
		else
			obj[k] = v -- TODO how do we handle object references.
		end
	end

	return obj -- return the restored object.
end

function deflate_object(obj)
	if type(obj) ~= 'table' or nil == obj.__gameObject then
		return nil -- Only work with game objects.
	end

	local data = getObjectProperties(obj)
	local exclude = {'inherit', 'actions', 'parent', '__gameObject'}
	for _,key in ipairs(exclude) do
		if nil ~= data[key] then
			data[key] = nil
		end
	end

	for key, val in pairs(data) do
		if key == 'inventory' then
			local sinv = {}
			for _,o in pairs(obj:getInventory()) do
				table.insert(sinv, deflate_object(o))
			end
			data['inventory'] = sinv
			-- end inventory

		elseif key == 'environment' then
			local env = obj:getEnv()
			data['environment'] = nil
			-- TODO maybe we should save this...

		elseif type(val) == 'table' then
			if nil ~= val.__gameObject then
				data[key] = deflate_object(val)
			else
				-- TODO iterate the table and see if any of the items in it
				-- need to be deflated.
			end
		end

		-- TODO We need to keep track of references to the main obj.
		-- if parent has already been deflated or is in the process of
		-- being so then only store the reference or perhaps nothing.
		-- When we inflate(restore) the object we'll call setEnv for
		-- each item.

	end -- end for

	return data
end

---
-- Called by engine when a player connects
--
function player_connects(line, client)
	cat(client, "/etc/welcome")

	-- Get name...
	local name = get_input(client, "What is your name? ", validate_login)

	local char
	if name == 'new' then
		char = create_new_character(client)
	elseif name == 'quit' then
		Net:send(client, "Goodbye!\n")
		Net:disconnect(client)
		return
	else
		char = login_character(client, name)
		if not char then
			Net:disconnect(client)
			return false
		end
	end

	chars[char.name] = char
	this_player = client
	char.client = client
	client.char = char
	client.handler = parseCommand

	for k,v in pairs(chars) do print (k, v.id) end

	-- Put player in world
	if char.playing ~= 1 then
		local dest = efun:find_object('/world/church')
		if nil == dest then
			dest = efun:clone_object('/world/church')
			if nil == dest then
				dprint("Start location could not be loaded... :(")
			end
		end
		char.playing = 1
		efun:move_object(char, dest)
	end

	efun:call_action(char, 'look')
	this_player = nil
	send_prompt(client)
end

---
-- Disconnects a player from the game.
-- called when the player types "quit".
-- Not to be misstaken with Net:disconnect()
-- which only disconnects the socket.
--
function disconnect_player(char)
	local client = char.client
	local name = char.cap_name
	local env = char:getEnv()

	char.playing = 0
	save_player(char)

	send("Bye bye!\n")
	Net:disconnect(client)

	chars[char.name] = nil
	efun:destroy_object(char)
	efun:tell_env(env, name .. " has quit the game.\n")
end

---
-- Login related code... might want to move this to login.lua
--

function create_new_character(client)
	Net:send(client, "Creating new character...\n")

	local name, yes_no, passwd, passwd2
	while true do
		name = get_input(client, "Choose a name: ", validate_new_character_name)
		if get_yes_no(client, "Your name is ".. name ..".\nIs this correct? [y/n]: ") then
			-- Client answered yes.
			break;
		end
		Net:send("\n")
	end -- end while

	while true do
		passwd = get_new_password(client, "Choose a password: ")
		passwd2 = get_password(client, "Type it again to confirm: ")
		if passwd == passwd2 then
			break
		else
			Net:send(client, "Passwords don't match. Try again.\n")
		end
	end -- end while

	local char = efun:clone_object('/std/player', {
		name = name,
		cap_name = capitalize(name),
		password = passwd, -- hash the password.
		created = os.time(),
	})

	save_player(char)

	return char
end


function login_character(client, name)
	local data = load_player(name)

	local retries, passwd = 3, nil
	while true do
		retries = retries - 1
		passwd = get_password(client, "Password: ")
		if passwd == data.password then
			break;
		end

		if retries == 0 then
			return nil
		end

		Net:send(client, "Wrong password, try again.\n")
	end

	local char
	if chars[name] then
		-- If we are already playing then disconnect the other
		-- instance and take over that char.
		char = chars[name]
		if nil ~= char.client then
			Net:send(char.client, "New connection established, giving up control!\n")
			Net:send(client, "Already playing, kicking out other copy!\n")
			Net:disconnect(char.client)
			char.client = nil
		else
			-- Probably a linkdead player...
			-- TODO handle linkdead.
		end
	else
		-- restore character
		char = restore_object(data)
		char.playing = 0
	end

	return char
end

function get_yes_no(client, query)
	local input
	while true do
		Net:send(client, query)
		input = string.lower( coroutine.yield() )

		if "yes" == input or "y" == input then
			return true
		elseif "no" == input or "n" == input then
			return false
		end -- end if

		Net:send(client, "Please answer 'yes' or 'no'.\n")
	end -- end while
end

function get_password(client, query)
	Net:send(client, query .. Telnet.WILL_ECHO)
	local password = coroutine.yield()
	Net:send(client, Telnet.WONT_ECHO .. "\n")

	return password
end

function get_new_password(client, query)
	local password

	while true do
		Net:send(client, query .. Telnet.WILL_ECHO)
		password = coroutine.yield()
		Net:send(client, Telnet.WONT_ECHO .. "\n")

		if string.len(password) == 0 then
			Net:send(client, "Password can't be empty.\n")
		elseif string.len(password) < 8 then
			Net:send(client, "Password too short, must be at least 8 characters.\n")
		else
			return password
		end -- end if
	end
end

function get_input(client, query, validator)
	local input
	while true do
		Net:send(client, query)
		input = string.lower( coroutine.yield() )

		if nil == validator then
			break;
		end

		local ok, err = validator(input)
		if ok then
			break;
		else
			Net:send(client, err .. "\n")
		end
	end -- end while

	return input
end

---
-- TODO add support for guest...
--
function validate_new_character_name(name)
	local ok, err = validate_name(name)
	if err then
		return false, err
	end

	if player_exists(name) then
		return false, "The name '" .. capitalize(name) .. "' is already taken."
	end

	return true
end

function validate_login(str)
	if str == 'new' or str == 'quit' then
		return str
	end

	local ok, err = validate_name(str)
	if err then
		return false, err
	end

	if not player_exists(str) then
		return false, capitalize(str) .. " does not exists."
	end

	return true
end

function validate_name(name)
	
	if string.len(name) == 0 then
		return false, "You can do better than that..."
	elseif not name:match("^%a+$") then
		return false, "Name must consist of letters only."
	end

	-- TODO block names god, shit, cock,
	return true
end
