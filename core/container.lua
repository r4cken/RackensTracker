local _, RT = ...

local table, setmetatable =
	  table, setmetatable

local Container = {}
RT.Container = Container

function Container:New()
	local data = {}
	setmetatable(data, self)
	self.__index = self
	data.byId = {}
	data.sorted = {}
	return data
end

-- NOTE: the object that is stored in Container must have a __lt function attached for sorting
-- Any object stored in Container must have a key "id" which can be a number or a string
function Container:Add(storageItem)
	if self.byId[storageItem.id] ~= nil then
		-- No need to track an already registered item in the container
		return false
	end

	self.byId[storageItem.id] = storageItem
	table.insert(self.sorted, storageItem)
	table.sort(self.sorted, function (a, b) return a < b end)
	return true
end