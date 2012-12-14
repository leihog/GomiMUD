inherit = "/std/object"

short_desc = "A boring room"
long_desc = "This room lacks a description..."
exits = {} -- List of exists ex: { south = "/vill_green" }
light = 1  -- All rooms are illuminated by default

__init = function(self)
	dprint("/std/room __init called...")
	parent.__init(self)

	efun:add_action(self, 'move', {
		'north', 'n',
		'south', 's',
		'west', 'w',
		'east', 'e',
		'up' , 'down',
		'northeast', 'ne',
		'northwest', 'nw',
		'southeast', 'se',
		'southwest', 'sw',
	})

end

function short(self)
	return self.short_desc
end

function long(self)
	return self.long_desc
end

-- TODO might want to move this to the player
move = function(self, ch, args)
	local dir, args = unpack(ch.last_cmd)
	
	local shortDirs = {
		n = 'north',
		s = 'south',
		w = 'west',
		e = 'east',
		ne = 'northeast',
		nw = 'northwest',
		se = 'southeast',
		sw = 'southwest'
	}

	if nil ~= shortDirs[dir] then
		dir = shortDirs[dir]
	end

	if nil == self.exits[dir] then
		send("You cannot go that way.\n")
		return true
	end

	ch:move(self.exits[dir], dir)
	return true
end
