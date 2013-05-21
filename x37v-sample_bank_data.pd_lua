
local X37VSampleBankData = pd.Class:new():register("x37v-sample_bank_data")

--this class simply stores the locations of samples,
--they can be named manually after a location is added,
--by default they are named with the last word in the soundfile location when
--the location is added
--
--idx are numerical
--
--input msgs: [-> output messages]
--
--|clear(	(clear all data)
--|get_name( -> |name "name"(
--|set_name "name"(
--|save location(
--|load location(
--
--|idx clear(
--|idx get( -> |idx location "location"(	(if it exists)
--|idx get_name( -> |idx name "name"(	(if the idx exists)
--|idx set "location"(
--|idx set_name "name"(	(if the idx exists)
--|get_all( (gets the data from all idxs, just like calling get_name and get for each idx)
--
--
--file format:
--["bank name"]
--idx	"soundfile_location"	"name"
--idx	"soundfile_location"	"name"
--...

function X37VSampleBankData:initialize(name, atoms)
	self.inlets = 1
	self.outlets = 1
	self.bank = {}
	self.name =  ""
	return true
end

function X37VSampleBankData:in_1_clear(l)
	self.bank = {}
	self.name =  ""
end

function X37VSampleBankData:in_1_get_name(l)
	self:outlet(1, "name", {self.name})
end

function X37VSampleBankData:in_1_set_name(l)
	if table.getn(l) == 1 then
		self.name = l[1]
	else
		self:error("|set_name " .. table.concat(l, " ") .. "( is not a valid message")
	end
end

function X37VSampleBankData:in_1_get_all(l)
	for i,item in pairs(self.bank) do
		self:outlet(1, "message", {i, "location", item["location"]})
		self:outlet(1, "message", {i, "name", item["name"]})
	end
end

function X37VSampleBankData:in_1_save(l)
	if table.getn(l) == 1 and type(l[1]) == "string" then
		local f = io.open(l[1], "w")
		if f == nil then
			self:error("|save " .. table.concat(l, " ") .. "( cannot open file to write")
			return
		end
		if self.name ~= "" then
			f:write("\"" .. self.name .. "\"\n")
		end
		for i,item in pairs(self.bank) do
			f:write(i .. "\t\"" .. item["location"] .. "\"\t\"" .. item["name"] .. "\"\n")
		end
		io.close(f)
	else
		self:error("|save " .. table.concat(l, " ") .. "( is not a valid message")
	end
end

function X37VSampleBankData:in_1_load(l)
	if table.getn(l) == 1 then
		local f = io.open(l[1], "r")
		if f == nil then
			self:error("|load " .. table.concat(l, " ") .. "( cannot open file to read")
			return
		end
		self.bank = {}
		self.name =  ""
		--grab a line
		for line in f:lines() do 
			local idx, loc, name = string.match(line, "^(%d+)%s\"(.*)\"%s\"(.*)\"")
			if name ~= nil then
				local new_item = {}
				--convert the index to a number
				idx = tonumber(idx)
				--ditch quotes in the name, make spaces into _
				name = string.gsub(name, "\"", "")
				name = string.gsub(name, "%s", "_")
				new_item["location"] = loc
				new_item["name"] = name
				self.bank[idx] = new_item
			else
				--ditch quotes, make spaces into _
				name = string.gsub(line, "\"", "")
				self.name = string.gsub(name, "%s", "_")
			end
		end
		io.close(f)
	else
		self:error("|load " .. table.concat(l, " ") .. "( is not a valid message")
	end
end

function X37VSampleBankData:in_1_list(l)
	local msg_len = table.getn(l)
	if table.getn(l) < 2 then
		self:error("|" .. table.concat(l, " ") .. "( is not a valid message")
		return
	end
	if msg_len == 1 then
		if l[2] == "clear" then
			if self.bank[l[1]] ~= nil then
				self.bank[l[1]] = nil
			end
		else
			self:error("|" .. table.concat(l, " ") .. "( is not a valid message")
			return
		end
	elseif msg_len == 2 then
		--make sure this index exists
		if self.bank[l[1]] == nil then
			self:error(l[1] .. " is not a valid bank index")
			return
		end
		--deal with the different messages
		if l[2] == "get" then
			self:outlet(1, "message", {l[1], "location", self.bank[l[1]]["location"]})
		elseif l[2] == "get_name" then
			self:outlet(1, "message", {l[1], "name", self.bank[l[1]]["name"]})
		else
			self:error("|" .. table.concat(l, " ") .. "( is not a valid message")
			return
		end
	elseif msg_len == 3 then
		if l[2] == "set_name" then
			if self.bank[l[1]] == nil then
				self:error(l[1] .. " is not a valid bank index")
			else
				self.bank[l[1]]["name"] = l[3]
			end
		elseif l[2] == "set" then
			local new_item = {}
			local new_name = l[3]

			--remove the suffix (ie .aiff)
			--remove the path
			--replace spaces with _
			new_name = string.gsub(new_name, "%.%a+$", "")
			new_name = string.match(new_name, "([^/]*)$")
			new_name = string.gsub(new_name, "%s", "_")

			new_item["location"] = l[3]
			new_item["name"] = new_name
			self.bank[l[1]] = new_item
		else
			self:error("|" .. table.concat(l, " ") .. "( is not a valid message")
			return
		end
	else
		self:error("|" .. table.concat(l, " ") .. "( is not a valid message")
		return
	end
end

