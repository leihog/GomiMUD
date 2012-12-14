inherit = "/std/room"

short_desc = "Village church"
long_desc = "You are in the local village church.\n" ..
	"There is a huge pit in the center,\n" ..
	"and a door in the west wall. " ..
	"There is a button beside the door.\n" ..
	"This church has the service of reviving ghosts. \n" ..
	"Dead people come to the church and pray."

exits = {
	south = "/world/vill_green",
}

__init = function(self)
	parent.__init(self)


	-- TODO move open to Player
	efun:add_action(self, 'opendoor', {'open'})
end

opendoor = function(self)
	self.exits['west'] = "/world/church_inner"
	send("You open the door.\n")
	return true
end
