---
-- Main
--

DEBUG = true

---
-- Load all the required scripts.
--
dofile("utils.lua")
dofile("efuns.lua")
dofile("net.lua")
dofile("telnet.lua")
dofile("file.lua")
JSON = (loadfile "JSON.lua")()

---
-- nil out any dangerous functions we don't want accessible
-- by game scripts.
--
local l_dofile = dofile

dofile     = nil
loadfile   = nil
require    = nil

-- safe version of os package
os = {
	date      = os.date,
	time      = os.time,
	setlocale = os.setlocale,
	clock     = os.clock,
	difftime  = os.difftime,
}

--TODO file.lua a safe version of the io package.

-- lib/init.lua is the main and only required file of the actual game.
-- This file acts as a configuration and entrypoint of the game code.
print("Loading game...")
l_dofile("lib/game.lua")
if nil == Game then
	print("Game object not found\nShutting down.")
	return 1
end

--TODO should we check for other required functions like player_connects?

-- Call the Game:init function if one exists.
local ok, err = pcall(Game.init, Game)
if not ok then
	dprint("Game object has no init function...")
end

local port = Game.port or 2000
Net:listen(port) -- Start listening for new connections
print ("MUD ready, on port " .. port)

repeat -- Main game loop
	Net:processQueue()
	-- TODO add trigger timed events / mobs etc...
	Net:accept() -- Handle new connections...

	-- Continue running while shutdown isn't in progress.
until efun:shutdown_in_progress()
