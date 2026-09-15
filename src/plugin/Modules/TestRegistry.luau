local TestRegistry = {}

local REQUIRED_FIELDS = {
	"id",
	"name",
	"category",
	"description",
	"timeout",
	"run",
}

local function isNonEmptyString(value)
	return type(value) == "string" and value:match("%S") ~= nil
end

local function validationError(definition)
	if type(definition) ~= "table" then
		return "module must return a test definition table"
	end

	for _, field in ipairs(REQUIRED_FIELDS) do
		if definition[field] == nil then
			return "missing required field '" .. field .. "'"
		end
	end

	for _, field in ipairs({ "id", "name", "category", "description" }) do
		if not isNonEmptyString(definition[field]) then
			return "field '" .. field .. "' must be a non-empty string"
		end
	end

	if type(definition.timeout) ~= "number"
		or definition.timeout <= 0
		or definition.timeout ~= definition.timeout
	then
		return "field 'timeout' must be a positive number"
	end

	if type(definition.run) ~= "function" then
		return "field 'run' must be a function"
	end

	return nil
end

function TestRegistry.discover(container)
	if typeof(container) ~= "Instance" then
		return {}, {
			{
				moduleName = "GameplayTests",
				path = "",
				message = "per-place test container is unavailable",
			},
		}
	end

	local candidates = {}
	for _, child in ipairs(container:GetChildren()) do
		if child:IsA("ModuleScript") and child.Name:match("Test$") then
			table.insert(candidates, child)
		end
	end
	table.sort(candidates, function(left, right)
		return left.Name < right.Name
	end)

	local tests = {}
	local errors = {}
	local seenIds = {}

	for _, moduleScript in ipairs(candidates) do
		local loaded, definition = pcall(require, moduleScript)
		local message
		if not loaded then
			message = "module failed to load: " .. tostring(definition)
		else
			message = validationError(definition)
		end

		if not message and seenIds[definition.id] then
			message = string.format(
				"duplicate test id '%s' (already used by %s)",
				definition.id,
				seenIds[definition.id]
			)
		end

		if message then
			table.insert(errors, {
				moduleName = moduleScript.Name,
				path = moduleScript:GetFullName(),
				message = message,
			})
		else
			seenIds[definition.id] = moduleScript.Name
			table.insert(tests, {
				id = definition.id,
				name = definition.name,
				category = definition.category,
				description = definition.description,
				timeout = definition.timeout,
				run = definition.run,
				module = moduleScript,
			})
		end
	end

	table.sort(tests, function(left, right)
		if left.category ~= right.category then
			return left.category < right.category
		end
		if left.name ~= right.name then
			return left.name < right.name
		end
		return left.id < right.id
	end)

	return tests, errors
end

function TestRegistry.findById(testId, container)
	local tests, errors = TestRegistry.discover(container)
	for _, test in ipairs(tests) do
		if test.id == testId then
			return test, nil, errors
		end
	end
	return nil, "Unknown or invalid BloxQA test: " .. tostring(testId), errors
end

return TestRegistry

