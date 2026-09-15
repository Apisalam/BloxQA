local HistoryStore = {}
HistoryStore.__index = HistoryStore

local DEFAULT_KEY = "BloxQA.ResultHistory.v1"
local MAX_ENTRIES = 20

local function copyEntry(entry)
	return {
		testId = entry.testId,
		testName = entry.testName,
		status = entry.status,
		durationMs = entry.durationMs,
		timestamp = entry.timestamp,
		errorMessage = entry.errorMessage,
	}
end

local function isValidEntry(entry)
	return type(entry) == "table"
		and type(entry.testId) == "string"
		and type(entry.testName) == "string"
		and (entry.status == "PASS" or entry.status == "FAIL")
		and type(entry.durationMs) == "number"
		and type(entry.timestamp) == "number"
		and (entry.errorMessage == nil or type(entry.errorMessage) == "string")
end

function HistoryStore.new(pluginInstance, settingKey)
	local self = setmetatable({
		plugin = pluginInstance,
		settingKey = settingKey or DEFAULT_KEY,
		entries = {},
		persistenceAvailable = true,
		persistenceError = nil,
	}, HistoryStore)

	local ok, stored = pcall(function()
		return pluginInstance:GetSetting(self.settingKey)
	end)
	if not ok then
		self.persistenceAvailable = false
		self.persistenceError = tostring(stored)
	elseif type(stored) == "table" then
		for _, entry in ipairs(stored) do
			if isValidEntry(entry) and #self.entries < MAX_ENTRIES then
				table.insert(self.entries, copyEntry(entry))
			end
		end
	end

	return self
end

function HistoryStore:_persist()
	local payload = {}
	for index, entry in ipairs(self.entries) do
		payload[index] = copyEntry(entry)
	end

	local ok, message = pcall(function()
		self.plugin:SetSetting(self.settingKey, payload)
	end)
	self.persistenceAvailable = ok
	if ok then
		self.persistenceError = nil
	else
		self.persistenceError = tostring(message)
	end
	return ok
end

function HistoryStore:add(test, result)
	local entry = {
		testId = test.id,
		testName = test.name,
		status = result.passed and "PASS" or "FAIL",
		durationMs = math.max(0, tonumber(result.durationMs) or 0),
		timestamp = os.time(),
		errorMessage = result.errorMessage and tostring(result.errorMessage) or nil,
	}
	table.insert(self.entries, 1, entry)
	while #self.entries > MAX_ENTRIES do
		table.remove(self.entries)
	end
	self:_persist()
	return copyEntry(entry)
end

function HistoryStore:getAll()
	local result = {}
	for index, entry in ipairs(self.entries) do
		result[index] = copyEntry(entry)
	end
	return result
end

function HistoryStore:getLatestByTestId()
	local latest = {}
	for _, entry in ipairs(self.entries) do
		if not latest[entry.testId] then
			latest[entry.testId] = copyEntry(entry)
		end
	end
	return latest
end

function HistoryStore:getPersistenceStatus()
	return {
		available = self.persistenceAvailable,
		errorMessage = self.persistenceError,
		settingKey = self.settingKey,
		limit = MAX_ENTRIES,
	}
end

return HistoryStore

