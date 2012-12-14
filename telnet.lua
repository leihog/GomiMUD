---
-- See:
--   http://tools.ietf.org/html/rfc1184
--   http://amylaar.pages.de/doc/concepts/negotiation
--


---
-- Telnet commands
--
local SE      = "\240" -- End of subnegotiation parameters
local NOP     = "\241" -- No operation
local DATMK   = "\242" -- Data stream portion of a sync
local BREAK   = "\243" -- NVT Character BRK
local IP      = "\244" -- Interrupt Process
local AO      = "\245" -- Abort Output
local AYT     = "\246" -- Are you there
local EC      = "\247" -- Erase Character
local EL      = "\248" -- Erase Line
local GA      = "\249" -- The Go Ahead Signal
local SB      = "\250" -- Sub-option to follow
local WILL    = "\251" -- Will; request or confirm option begin
local WONT    = "\252" -- Wont; deny option request
local DO      = "\253" -- Do = Request or confirm remote option
local DONT    = "\254" -- Don't = Demand or confirm option halt
local IAC     = "\255" -- Interpret as Command
local SEND    = "\001" -- Sub-process negotiation SEND command
local IS      = "\000" -- Sub-process negotiation IS command

---
-- Telnet options
--
local ECHO = "\001"
local LINEMODE = "\034"
local TTYPE = "\024"

---
-- Linemode options
--

local MODE_EDIT = "\001"


local Session = {}

function Session:check_input(line)

	-- TODO extract control codes and handle them...
	-- since we are now in object context specific for the client
	-- we should store the clients current telnet modes/options...

	local _line = line
	local tmp
	while string.len(line) > 0 do
		tmp = line:sub(1,1) -- cut off the first character.
		line = line:sub(2)

		-- pattern matches all non alphanum/punctuation/whitespace
		if tmp:match("[^%w%s%p]") then
			print( 'got: ' .. string.byte(tmp) )
		end
	end

	return string.gsub(_line, IAC.."["..DO..DONT..WILL..WONT.."].", "")
end

Telnet = {
	WILL_ECHO = IAC .. WILL .. ECHO,
	WONT_ECHO = IAC .. WONT .. ECHO,

	new = function(client)
		local sess = class(nil, Session)
		return sess:create({
			client = client
		})
	end
}
