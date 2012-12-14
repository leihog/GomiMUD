dprint "Loading sockets library..."
local socket = require("socket")
--local sockets = {}
--local server

Net = {
	sockets = {},
	server = nil,
}

function Net:listen(port)
	dprint "Binding server port ..."
	-- create a TCP socket and bind it to the local host
	local server = assert(socket.bind("*", port))
	server:settimeout(0)  -- do not block waiting for client connections
	self.server = server
end

function Net:shutdown()
	self.server:close()
	self.server = nil
end

---
-- Accepts new connections and sends them to
-- Net:new() unless server has been shutdown.
function Net:accept()
	if nil == self.server then
		return
	end

	local socket
	repeat
		socket = self.server:accept()
		if socket then
			self:new(socket)
		end
	until not socket
end

---
-- Called when we get a new connection
--
function Net:new(s)
	ip, port = s:getpeername()
	print ("New connection from", ip, "port", port)
	s:settimeout(0)

	local client = {}
	self.sockets[s] = client

	client.socket = s
	client.connected = os.time()

	client.telnet = Telnet:new(client)

	-- client.handler is a function that handles input from this socket.
	-- the handler is always run in it's own coroutine which is handy because
	-- it lets us pause (yield) the handler and wait for more input.
	client.handler = player_connects
	client.thread = coroutine.create(client.handler)
	assert (coroutine.resume(client.thread, nil, client))

end

function Net:read(s)
	local line, err, partial = s:receive()
	if err then
		if err == 'timeout' then
			line = partial
		else
			self:remove(s)
			return false
		end
	end

	local client = self.sockets[s]
	client.ping = os.time()

	--line = telnet_negotiate(line, client)
	line = client.telnet:check_input(line)
	if not(line) or line == "" then
		return
	end

	-- Check if client has an active coroutine, and if not create one.
	if not client.thread or coroutine.status(client.thread) ~= "suspended" then
		client.thread = coroutine.create(client.handler)
	end
	
	-- let worker thread do something with input line
	local ok, err = coroutine.resume(client.thread, line, client)
	
	if not ok then
		print ("Got error", err, "from socket", s)
		self:send(client,
			"\n\nAn server error occurred, this has been logged.\n"..
			"Press <enter> to continue ..."
			)
		client.thread = nil
	end
end

function Net:readQueue()
	local t = {}
	for s in pairs(self.sockets) do
		table.insert(t, s)
	end

	local readable, _, err = socket.select(t, nil, 1)
	for _,s in ipairs(readable) do
		self:read(s)
	end
end

---
--TODO adjust this to work more like write in Minion bot where it tries
--to send whole lines...
function Net:write(s)
	local client = self.sockets[s]
	assert (client.socket == s, "client/socket pair not found")

	local len = math.min(string.len(client.output), 2048) -- 2048 bytes to send.
	local count, err, count2 = s:send(client.output, 1, len)

	-- timeout just means we are trying to send too much
	if err and err == "timeout" then
		err = nil
		count = count2
	end -- timeout

	-- other errors? drop client
	if err then
		print ("Error in send", err)
		self:remove(s)
	else
		client.output = string.sub(client.output, count + 1)
		if string.len(client.output) <= 0 then
			client.output = nil
		end
	end
end

function Net:disconnect(client)
	if client.output then
		-- TODO while until client.output is empty.
		self:write(client.socket)
	end

	Net:remove(client.socket)
end

function Net:writeQueue()
	local t = {}
	for s in pairs(self.sockets) do
		if self.sockets[s].output then
			table.insert(t, s)
		end
	end

	local _, writeable, err = socket.select(nil, t, 0)
	for _, s in ipairs(writeable) do
		self:write(s)
	end
end

function Net:processQueue()
	self:writeQueue()
	self:readQueue()
end

function Net:remove(socket)
	socket:close()

	local client = self.sockets[socket]
	--TODO make sure that we can remove an item in a table like this.
	self.sockets[socket] = nil -- that socket not in use now
	client.socket = nil

	-- Trigger player_disconnect()
	--[[
	if client.name then
		--SaveCharacter(client.name)  -- save him  
		chars[client.name] = nil
		print(client.name, "has left the game")
	end -- removing character too
	--]]
	print ("Removed client socket", socket)
end

---
-- Queue output for client
function Net:send(client, str)
	if nil == str then
		return
	end
	client.output = (client.output or "" ).. str
end
