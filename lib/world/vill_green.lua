inherit = "/std/room"

short_desc = "Village green"
long_desc = "You are at an open green place south of the village church."
exits = {
	north = "/world/church"
}

function __init(self)
	parent.__init(self)

	self:create_rock({
		aliases = {"small rock", "rock"},
		short_desc = "A small rock",
		long_desc = "There is nothing special about it."
	})

	self:create_rock({
		aliases = {"large rock", "rock"},
		short_desc = "A large rock",
		long_desc = "As far as rocks go, this one is rather big."
	})
end

function create_rock(self, def)
	local rock = efun:clone_object('/std/object', def)
	efun:move_object(rock, self)
end
