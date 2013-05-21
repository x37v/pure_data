-- step sequencer by alex
-- helper functions

function isNumList(l)
	for _,v in pairs(l) do
		if type(v) ~= "number" then
			return false
		end
	end
	return true
end

function table.add(t1,t2)
	local res = t1
	for _,v in pairs(t2) do
		table.insert(res,v)
	end
	return res
end

function table.deepcopy(source)
	local dest = {}
	if type(source) ~= "table" then return dest end
	for i,v in pairs(source) do
		if type(v) ~= "table" then
			dest[i] = v
		else
			dest[i] = table.deepcopy(v)
		end
	end
	return dest
end

--this allows for strings to be compared to numbers
--numbers are always less than anything else
--tables are always greater than anything else 
--we only check the first element of the table.
function less_than(x,y)
	if type(x) == "table" then
		--if y is a table then test, otherwise, tables are always at the end of the list
		--always less than anything else
		if type(y) == "table" then
			if table.getn(x) > 0 and table.getn(x) > 0 then
				return less_than(x[1],y[1])
			end
		else
			return false
		end
	elseif type(x) == "number" then
		if type(y) == "number" then
			return x < y
		else
			return true
		end
		--tables are always at the end of the list
	elseif type(y) == "table" then
		return true
	else
		if type(y) == "number" then
			return false
		else
			return tostring(x) < tostring(y)
		end
	end
end

-- Pd class

local X37VStepSeq = pd.Class:new():register("x37v-step_seq")

--outlet 1, the sequence info
--outlet 2, the step number
--outlet 3, status
function X37VStepSeq:initialize(name, atoms)
	self.inlets = 1
	self.outlets = 3
	self.index = 1
	self.play_page = 1
	self.edit_page = 1
	self.toggle = false

	--[[
	self.play_page_next = nil
	self.chain = {}
	self.chain_index = 1
	--]]

	if atoms[1] ~= nil and type(atoms[1]) == "number" and atoms[1] > 0 then
		self.length = math.floor(atoms[1])
	else
		self.length = 16
	end
	self.sequence = {}
	self.sequence[1] = {}
	return true
end

function X37VStepSeq:in_1_length(l)
	if table.getn(l) == 0 then
		self:outlet(3, "length", {self.length})
	elseif table.getn(l) == 1 and type(l[1]) == "number" and l[1] > 0 then
		self.length = math.floor(l[1])
	else
		self:error("|length " .. table.concat(l, " ") .. "( is not a valid message")
	end
end

function X37VStepSeq:in_1_play_page(l)
	if table.getn(l) == 1 then
		--[[
		--setting the play page invalidates the next play page or the chain
		self.play_page_next = nil
		self.chain = {}
		--]]
		if type(l[1]) == "number" then
			self.play_page = l[1] + 1
		else
			self.play_page = l[1]
		end
		if self.sequence[self.play_page] == nil then
			self.sequence[self.play_page] = {}
		end
		self:outlet(3, "play_page", {l[1]})
	else
		self:error("|play_page " .. table.concat(l, " ") .. "( is not a valid message")
	end
end

--[[
function X37VStepSeq:in_1_next_play_page(l)
	if table.getn(l) == 1 then
		--we stop chaining if we're setting the next play page
		self.chain = {}
		self.chain_index = 1
		if type(l[1]) == "number" then
			self.play_page_next = l[1] + 1
		else
			self.play_page_next = l[1]
		end
		if self.sequence[self.play_page_next] == nil then
			self.sequence[self.play_page_next] = {}
		end
	else
		self:error("|next_play_page " .. table.concat(l, " ") .. "( is not a valid message")
	end
end

function X37VStepSeq:in_1_chain(l)
	if table.getn(l) >= 1 then
		--init the chain and index, also set play_page_next to nil
		self.chain = {}
		self.chain_index = 1
		self.play_page_next = nil
		for _,v in pairs(l) do
			local p = v
			if type(p) == "number" then
				p = v + 1
			end
			if self.sequence[p] ~= nil then
				table.insert(self.chain,p)
			else
				--if the table doesn't exist, create it
				self.sequence[p] = {}
				table.insert(self.chain,p)
				--XXX should warn?
				--self:error("|chain " .. table.concat(l, " ") .. "( page " .. v .. " does not exist, creating it")
			end
		end
		self:outlet(3, "chain", l)
	else
		self:error("|chain " .. table.concat(l, " ") .. "( is not a valid message")
	end
end
--]]

function X37VStepSeq:in_1_edit_page(l)
	if table.getn(l) == 1 then
		if type(l[1]) == "number" then
			self.edit_page = l[1] + 1
		else
			self.edit_page = l[1]
		end
		if self.sequence[self.edit_page] == nil then
			self.sequence[self.edit_page] = {}
		end
	else
		self:error("|edit_page " .. table.concat(l, " ") .. "( is not a valid message")
	end
end

function X37VStepSeq:in_1_copy_page(l)
	if table.getn(l) == 2 then
		local page1 = l[1]
		local page2 = l[2]
		--i like to start with 0 but lua uses 1 so, reformat a number that comes in
		if type(page1) == "number" then
			page1 = page1 + 1
		end
		if type(page2) == "number" then
			page2 = page2 + 1
		end
		if self.sequence[page1] == nil then
			self:error("|copy_page " .. table.concat(l, " ") .. "( refers an invalid source page")
			return
		end
		self.sequence[page2] = table.deepcopy(self.sequence[page1])
	else
		self:error("|copy_page " .. table.concat(l, " ") .. "( is not a valid message")
	end
end

function X37VStepSeq:in_1_toggle(l)
	if table.getn(l) == 0 then
		self.toggle = not self.toggle
	elseif l[1] == 0 then
		self.toggle = false
	else
		self.toggle = true
	end
end

function X37VStepSeq:in_1_get(l)
	local msglen = table.getn(l)
	if msglen == 1 then
		if l[1] == "length" then
			self:outlet(3, "length", {self.length})
		elseif l[1] == "play_page" then
			if type(self.play_page) == "number" then
				self:outlet(3, "play_page", {self.play_page - 1})
			else
				self:outlet(3, "play_page", {self.play_page})
			end
		elseif l[1] == "edit_page" then
			if type(self.edit_page) == "number" then
				self:outlet(3, "edit_page", {self.edit_page - 1})
			else
				self:outlet(3, "edit_page", {self.edit_page})
			end
		elseif l[1] == "page_contents" then
			for i,s in pairs(self.sequence[self.edit_page]) do
				if s ~= nil then
					for _,v in pairs(s) do
						--output 'contents', index, item
						self:outlet(3, "contents", table.add({i - 1}, v))
					end
				end
			end
		else
			self:error("|get " .. table.concat(l, " ") .. "( is not a valid message")
			return
		end
	elseif msglen == 2 then
		--query the values at a step
		if l[1] == "step" and type(l[2]) == "number" and l[2] >= 0 and l[2] < self.length then
			local index = math.floor(l[2]) + 1
			if self.sequence[self.edit_page][index] == nil then return end
			for _,v in pairs(self.sequence[self.edit_page][index]) do
				self:outlet(3, "step", table.add({math.floor(l[2])},v))
			end
		elseif l[1] == "item" then
			--in each step search for a message prefixed with l[2]
			--if found, output |item l[2] stepnum restofmessage..(
			for i,s in pairs(self.sequence[self.edit_page]) do
				if s ~= nil then
					for _,v in pairs(s) do
						if v[1] == l[2] then
							local rest = {}
							for j = 2,table.getn(v) do
								table.insert(rest,v[j])
							end
							self:outlet(3, "item", table.add({v[1], i - 1}, rest))
						end
					end
				end
			end
		else
			self:error("|get " .. table.concat(l, " ") .. "( is not a valid message")
			return
		end
	else
		self:error("|get " .. table.concat(l, " ") .. "( is not a valid message")
		return
	end
end

--add items to our sequence
--|step index ...( where "index" is unique and there can be more after the
--index for instance |0 toast 2( will insert |toast 2( at step 0
--|0 toast 2 x( will replace toast 2 with toast 2 x
function X37VStepSeq:in_1_list(l)
	if table.getn(l) < 2 then return end
	--make sure the in list is long enough, the first value is an index
	--and the index is in range
	
	if type(l[1])  == "number" and l[1] >= 0 and l[1] < self.length then
		local index = math.floor(l[1]) + 1
		local newelem = {}
		for i = 2, table.getn(l) do
			table.insert(newelem, l[i])
		end
		if self.sequence[self.edit_page][index] == nil then
			self.sequence[self.edit_page][index] = {newelem}
		else
			--is this index already in this step
			for i,v in pairs(self.sequence[self.edit_page][index]) do
				if v[1] == newelem[1] then
					if self.toggle then
						self.sequence[self.edit_page][index][i] = nil
					else
						self.sequence[self.edit_page][index][i] = newelem
					end
					return
				end
			end
			table.insert(self.sequence[self.edit_page][index], newelem)
			table.sort(self.sequence[self.edit_page][index], less_than)
		end
	end
end

--clears the whole sequence
function X37VStepSeq:in_1_clear_all(l)
	self.sequence = {}
	self.sequence[self.edit_page] = {}
end

--clears a page
function X37VStepSeq:in_1_clear_page(l)
	if table.getn(l) == 1 and self.sequence[l[1]] ~= nil then
		self.sequence[l[1]] = {}
	end
end

--clear
--a |clear( clears the whole page
--a |clear index( clears messages that start with 'index' from all steps in the edit page
--a |clear index step( clears messages that start with 'index' from step "step" in the edit page
function X37VStepSeq:in_1_clear(l)
	local len = table.getn(l)
	if len == 0 then
		self.sequence[self.edit_page] = {}
	elseif len == 1 then
		--search all steps
		for _,step in pairs(self.sequence[self.edit_page]) do
			--if the step is not nil then search the step
			if step ~= nil then
				for i,v in pairs(step) do
					--if our clear 'index' matches the first
					--value of our sequenced message, remove it
					if v[1] == l[1] then
						table.remove(step,i)
						--we can break because we only have message per index per step
						break
					end
				end
			end
		end
	elseif len == 2 and type(l[2]) == "number" then
		local index = math.floor(l[2] + 1)
		--if the step is not nil then search the step
		if self.sequence[self.edit_page][index] ~= nil then
			for i,v in pairs(self.sequence[self.edit_page][index]) do
				--if our clear 'index' matches the first
				--value of our sequenced message, remove it
				if v[1] == l[1] then
					table.remove(self.sequence[self.edit_page][index],i)
					--we can break because we only have message per index per step
					break
				end
			end
		end
	else
		self:error("|clear " .. table.concat(l, " ") .. "( is not a valid message")
	end
end

--clears all values from one step
function X37VStepSeq:in_1_clear_step(l)
	if table.getn(l) == 1 and type(l[1]) == "number" then
		local index = math.floor(l[1] + 1)
		if index <= self.length and index > 0 then
			self.sequence[self.edit_page][index] = nil
		else
			self:error("|clear_step " .. l[1] .. "( step index out of range")
		end
	else
		self:error("|clear_step " .. table.concat(l, " ") .. "( is not a valid message")
	end
end

--set the index
function X37VStepSeq:in_1_index(l)
	if table.getn(l) < 1 or type(l[1]) ~= "number" then 
		return 
	end
	self.index = math.floor(l[1] + 1)
	--make sure the index is in range
	if self.index > self.length then
		self.index = 1
	elseif self.index < 1 then
		self.index = 1
	end
end

function X37VStepSeq:in_1_reset(l)
	self.index = 1
	--[[
	--on reset, we set the play index to 1 and the chain index to 1
	--we update the play page to be equal to the next play page 
	--or the first page in the chain [if we're chaining]
	self.chain_index = 1
	if self.play_page_next ~= nil then
		self.play_page = self.play_page_next
		self.play_page_next = nil
	elseif table.getn(self.chain) > 0 then
		self.play_page = self.chain[1]
		self:outlet(3, "chain_index", {0})
		self.chain_index = self.chain_index + 1
		if self.chain_index > table.getn(self.chain) then
			self.chain_index = 1
		end
	end
	--]]

	--update our status
	if type(self.play_page) == "number" then
		self:outlet(3, "play_page", {self.play_page - 1})
	else
		self:outlet(3, "play_page", {self.play_page})
	end
end

function X37VStepSeq:in_1_bang()
	self:in_1_float(self.index - 1)
end

function X37VStepSeq:in_1_float(f)
	local index = math.floor(f + 1)

	--make sure we're in range
	if not (index > 0 and index < (self.length + 1)) then return end

	--output the index
	self:outlet(2, "float", {index - 1})

	--output the items at this step
	if self.sequence[self.play_page][index] ~= nil then
		for _,v in pairs(self.sequence[self.play_page][index]) do
			if isNumList(v) then
				self:outlet(1, "list", v)
			else
				local rest = {}
				for i = 2,table.getn(v) do
					table.insert(rest, v[i])
				end
				self:outlet(1, v[1], rest)
			end
		end
	end

	--increment the index
	self.index = index + 1
	if self.index > self.length then
		self.index = 1

		--[[
		--if we've set up a next page to play then play that
		--otherwise, if we are chaining then follow the chain
		if self.play_page_next ~= nil then
			self.play_page = self.play_page_next
			self.play_page_next = nil

			--output the new play page
			if type(self.play_page) == "number" then
				self:outlet(3, "play_page", {self.play_page - 1})
			else
				self:outlet(3, "play_page", {self.play_page})
			end
		elseif table.getn(self.chain) > 0 then
			self.play_page = self.chain[self.chain_index]
			--output the new play page
			if type(self.play_page) == "number" then
				self:outlet(3, "play_page", {self.play_page - 1})
			else
				self:outlet(3, "play_page", {self.play_page})
			end
			self:outlet(3, "chain_index", {self.chain_index - 1})
			--increment the chain index
			--we do this after setting the new pattern intentionally because
			--we don't jump to the first pattern in the chain until after current
			--pattern ends
			self.chain_index = self.chain_index + 1
			if self.chain_index > table.getn(self.chain) then
				self.chain_index = 1
			end
		end
		--]]
		
		--indicate that we've reached the end of this sequence
		self:outlet(3, "end", {})
	end
end

function X37VStepSeq:in_1_load(l)
	if table.getn(l) == 1 and type(l[1]) == "string" then
		local f = io.open(l[1], "r")
		if f == nil then
			self:error("|load " .. table.concat(l, " ") .. "( cannot open file to read")
			return
		end
		self.sequence = {}
		self.sequence[1] = {}
		--grab a line
		for line in f:lines() do 
			local items = {}
			--get each item out of the line
			for item in string.gmatch(line,"[^%s]+") do
				table.insert(items,item)
			end
			if table.getn(items) > 2 then
				local page = items[1]
				local step = tonumber(items[2])
				--fix up numbers
				if tonumber(page) ~= nil then page = tonumber(page) + 1 end
				--tonumber returns nil if it cannot convert to a number
				if step == nil then
					--XXX print error
				else
					step = step + 1
					if self.sequence[page] == nil then 
						self.sequence[page] = {} 
					end
					local newentry = {}
					for i = 3,table.getn(items) do
						if tonumber(items[i]) then
							table.insert(newentry, tonumber(items[i]))
						else
							table.insert(newentry, items[i])
						end
					end
					if self.sequence[page][step] == nil then 
						self.sequence[page][step] = {newentry}
					else
						table.insert(self.sequence[page][step], newentry)
					end
				end
			else
				--XXX print error
			end
		end
		io.close(f)
	else
		self:error("|load " .. table.concat(l, " ") .. "( is not a valid message")
	end
end

function X37VStepSeq:in_1_save(l)
	if table.getn(l) == 1 and type(l[1]) == "string" then
		local f = io.open(l[1], "w")
		if f == nil then
			self:error("|save " .. table.concat(l, " ") .. "( cannot open file to write")
			return
		end
		for i,p in pairs(self.sequence) do
			--fix up indexing
			local page = i
			if type(page) == "number" then
				page = page - 1
			end
			for j,s in pairs(p) do
				--fix up indexing
				local step = j - 1
				for k,item in pairs(s) do
					--output page\tstep\tindex\trest
					f:write(page .. "\t" .. step)
					for _,j in pairs(item) do
						f:write("\t" .. j)
					end
					f:write("\n")
				end
			end
		end
		io.close(f)
	else
		self:error("|save " .. table.concat(l, " ") .. "( is not a valid message")
	end
end


