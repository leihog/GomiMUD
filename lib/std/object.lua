id = nil

-- Used as a simple way to tell if a table is a game object.
__gameObject = true --TODO this could be set in the class:create function

name = "standard object"
short_desc = "A standard object"
long_desc = "The standard object lacks a description"

function __init(self)
	dprint("Object __init called...")

	self.actions = {}
	self.environment = nil
	self.inventory = {}
end

function id_as(self, str)
	if self.aliases then
		for _, a in ipairs(self.aliases) do
			if a == str then return true end
		end
	end

	if self.name and str == self.name then return true end
	return false
end

function short(self)
	return self.short_desc
end

function long(self)
	return self.long_desc
end

function addInventory(self, obj)
	if nil == self.inventory[obj.id] then
		self.inventory[obj.id] = obj
	end
end

function removeInventory(self, obj)
	if nil ~= self.inventory[obj.id] then
		self.inventory[obj.id] = nil
	end
end

function getInventory(self)
	return self.inventory
end

function setEnv(self, obj)
	self.environment = obj
end

function getEnv(self)
	return self.environment or nil
end

-- Setup some defaults that can be overriden.
enter_inv = function(self)
	send("Something just entered ".. self.short .."\n")
end

leave_inv = function(self)
end

enter_env = function(self)
end

leave_env = function(self)
end
