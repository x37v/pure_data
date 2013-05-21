-- x37v-arp by Alex Norman http://x37v.info
-- This is a user configurable arpeggiator.
--
-- Users specify data to arpeggiate over and (optionally) a pattern to use to access this data, 
-- and (optionally) an increment index list to use to specify how to apply the pattern to the data.
--
-- The pattern can be randomized as can the increment.

local X37VArp = pd.Class:new():register("x37v-arp")

--
-- arp [list]: the data to output
-- pattern [list]: how to access the data
-- increment [list]: used with pattern to access the data

function X37VArp:initialize(name, atoms)
	self.inlets = 1
	self.outlets = 1

	self.arp = {}
	self.pattern = {0}
	self.increment = {1}

	self.pattern_index = 0
	self.increment_index = 0
	self.arp_offset = 0

	self.random = false
	self.random_increment = false
	return true
end

function X37VArp:Outlet(num, atom)
    -- a better outlet: automatically selects selector
    -- map lua types to pd selectors
    local selectormap = {string = "symbol", number="float", userdata="pointer"}
    self:outlet(num, selectormap[type(atom)], {atom})
end

function X37VArp:in_1(sel, atoms)
	self.arp = {sel}
	for i=1,table.getn(atoms) do
		table.insert(self.arp, atoms[i])
	end
	
	--if our current index is out of range of this new pattern, set the index to zero
	if self.arp_offset >= table.getn(self.arp) then
		self.arp_offset = 0
	end
end

function X37VArp:in_1_list(l)
	self.arp = l
	--if our current index is out of range of this new pattern, set the index to zero
	if self.arp_offset >= table.getn(self.arp) then
		self.arp_offset = 0
	end
end

function X37VArp:in_1_reset(l)
	self.pattern_index = 0
	self.increment_index = 0
	self.arp_offset = 0
end

function X37VArp:in_1_pattern(l)
	self.random = false
	self.increment_index = 0
	if table.getn(l) > 0 then
		self.pattern = l
		self.pattern_index = 0
	else
		self.pattern = {0}
		self.pattern_index = 0
	end
end

function X37VArp:in_1_increment(l)
	self.random_increment = false
	self.pattern_index = 0
	if table.getn(l) > 0 then
		self.increment = l
		self.increment_index = 0
	else
		self.increment = {1}
		self.increment_index = 0
	end
end

function X37VArp:in_1_random(l)
	if table.getn(l) > 0 then
		if l[1] == 1 or l[1] == true then
			self.random = true
		else
			self.random = false
		end
	else
		self.random = true
	end
end

function X37VArp:in_1_random_increment(l)
	if table.getn(l) > 0 then
		if l[1] == 1 or l[1] == true then
			self.random_increment = true
		else
			self.random_increment = false
		end
	else
		self.random_increment = true
	end
end

function X37VArp:in_1_bang()
	local arp_len = table.getn(self.arp)
	local pat_len = table.getn(self.pattern)
	local inc_len = table.getn(self.increment)

	--if we don't have any data to arp on then don't outlet anything
	if arp_len == 0 then
		return
	end
	if pat_len == 0 then
		--XXX send a warning
		return
	end
	
	if self.random then
		self:Outlet(1, self.arp[math.random(arp_len)])
	else
		--outlet the next item
		self:Outlet(1, self.arp[1 + math.mod(self.pattern[self.pattern_index + 1] + self.arp_offset, arp_len)])

		--update the indices
		self.pattern_index = self.pattern_index + 1

		--if we've finished the pattern update the offset
		if self.pattern_index >= pat_len then
			self.pattern_index = 0
			if self.random_increment then
				self.arp_offset = math.random(arp_len) - 1
			else
				local new_offset = self.arp_offset + self.increment[self.increment_index + 1] 
				--if the new offset will overflow our pattern, see if we need to update
				if (new_offset >= arp_len or new_offset < 0) and inc_len > 0 then
					--update our increment index and also update our new arp_offset
					self.increment_index = math.mod(self.increment_index + 1, inc_len)
					new_offset = math.mod(self.arp_offset + self.increment[self.increment_index + 1], arp_len) 
				end

				--make sure we're in bounds
				if new_offset >= arp_len then
					self.arp_offset = math.mod(self.arp_offset + self.increment[self.increment_index + 1], arp_len) 
				elseif new_offset < 0 then
					self.arp_offset = math.mod(arp_len + math.mod(self.arp_offset + self.increment[self.increment_index + 1], arp_len), arp_len)
				else
					self.arp_offset = new_offset
				end
			end
		end
	end
end

