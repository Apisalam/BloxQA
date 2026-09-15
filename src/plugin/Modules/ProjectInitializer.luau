local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local RuntimeTemplate = require(script.Parent:WaitForChild("RuntimeTemplate"))

local ProjectInitializer = {}

local OWNER_ATTRIBUTE = "BloxQAOwned"
local SCHEMA_ATTRIBUTE = "BloxQASchemaVersion"
local RUNTIME_ATTRIBUTE = "BloxQARuntimeVersion"
local SCHEMA_VERSION = 1
local RUNTIME_VERSION = "0.2.0-dev"

local REQUIRED_ROOT_CHILDREN = {
	TestRunner = "ModuleScript",
	TestRegistry = "ModuleScript",
	TestContext = "ModuleScript",
	StudioTestController = "ModuleScript",
	Version = "ModuleScript",
	GameplayTests = "Folder",
}

local REQUIRED_GAMEPLAY_CHILDREN = {
	CharacterTestUtils = "ModuleScript",
	PlayerSpawnTest = "ModuleScript",
	PlayerRespawnTest = "ModuleScript",
	ExampleTestTemplate = "ModuleScript",
}

local function isOwned(instance)
	return instance ~= nil and instance:GetAttribute(OWNER_ATTRIBUTE) == true
end

local function metadataMatches(instance)
	return instance:GetAttribute(SCHEMA_ATTRIBUTE) == SCHEMA_VERSION
		and instance:GetAttribute(RUNTIME_ATTRIBUTE) == RUNTIME_VERSION
end

local function addIssue(issues, message, repairable)
	table.insert(issues, message)
	return repairable
end

function ProjectInitializer.inspect()
	local root = ReplicatedStorage:FindFirstChild("BloxQA")
	local harness = ServerScriptService:FindFirstChild("BloxQAGameplayTestServer")

	if not root and not harness then
		return {
			state = "missing",
			healthy = false,
			repairable = false,
			message = "No BloxQA project detected.",
			issues = {},
		}
	end

	local issues = {}
	local repairable = true

	if root then
		if not root:IsA("Folder") then
			repairable = addIssue(issues, "ReplicatedStorage.BloxQA must be a Folder; existing object was not changed.", false)
		elseif not isOwned(root) then
			repairable = addIssue(issues, "ReplicatedStorage.BloxQA is not marked as BloxQA-owned; existing content was not changed.", false)
		elseif root:GetAttribute(SCHEMA_ATTRIBUTE) ~= SCHEMA_VERSION then
			repairable = addIssue(issues, "Runtime schema is unsupported and requires a future migration.", false)
		else
			if root:GetAttribute(RUNTIME_ATTRIBUTE) ~= RUNTIME_VERSION then
				repairable = addIssue(issues, "Runtime version metadata does not match " .. RUNTIME_VERSION .. ".", false)
			end
			for name, className in pairs(REQUIRED_ROOT_CHILDREN) do
				local child = root:FindFirstChild(name)
				if not child then
					repairable = addIssue(issues, "Missing ReplicatedStorage.BloxQA." .. name .. ".", repairable)
				elseif child.ClassName ~= className then
					repairable = addIssue(
						issues,
						string.format("ReplicatedStorage.BloxQA.%s must be a %s; existing object was not changed.", name, className),
						false
					)
				elseif not isOwned(child) then
					repairable = addIssue(issues, "ReplicatedStorage.BloxQA." .. name .. " is not marked as BloxQA-owned; existing content was not changed.", false)
				elseif not metadataMatches(child) then
					repairable = addIssue(issues, "ReplicatedStorage.BloxQA." .. name .. " metadata does not match the current runtime.", false)
				end
			end

			local gameplayTests = root:FindFirstChild("GameplayTests")
			if gameplayTests and gameplayTests:IsA("Folder") and isOwned(gameplayTests) and metadataMatches(gameplayTests) then
				for name, className in pairs(REQUIRED_GAMEPLAY_CHILDREN) do
					local child = gameplayTests:FindFirstChild(name)
					if not child then
						repairable = addIssue(issues, "Missing ReplicatedStorage.BloxQA.GameplayTests." .. name .. ".", repairable)
					elseif child.ClassName ~= className then
						repairable = addIssue(issues, "ReplicatedStorage.BloxQA.GameplayTests." .. name .. " must be a " .. className .. "; existing object was not changed.", false)
					elseif not isOwned(child) then
						repairable = addIssue(issues, "ReplicatedStorage.BloxQA.GameplayTests." .. name .. " is not marked as BloxQA-owned; existing content was not changed.", false)
					elseif not metadataMatches(child) then
						repairable = addIssue(issues, "ReplicatedStorage.BloxQA.GameplayTests." .. name .. " metadata does not match the current runtime.", false)
					end
				end
			end
		end
	else
		repairable = addIssue(issues, "Missing ReplicatedStorage.BloxQA.", repairable and isOwned(harness))
	end

	if harness then
		if not harness:IsA("Script") then
			repairable = addIssue(issues, "ServerScriptService.BloxQAGameplayTestServer must be a Script; existing object was not changed.", false)
		elseif not isOwned(harness) then
			repairable = addIssue(issues, "ServerScriptService.BloxQAGameplayTestServer is not marked as BloxQA-owned; existing content was not changed.", false)
		elseif not metadataMatches(harness) then
			repairable = addIssue(issues, "Server harness metadata does not match the current runtime.", false)
		end
	else
		repairable = addIssue(issues, "Missing ServerScriptService.BloxQAGameplayTestServer.", repairable and isOwned(root))
	end

	local healthy = #issues == 0
	return {
		state = healthy and "healthy" or "incomplete",
		healthy = healthy,
		repairable = not healthy and repairable,
		message = healthy and "Project Ready" or "BloxQA installation is incomplete or incompatible.",
		issues = issues,
		root = root,
		harness = harness,
	}
end

local function instantiate(descriptor)
	local instance = Instance.new(descriptor.className)
	instance.Name = descriptor.name
	if descriptor.source then
		instance.Source = descriptor.source
	end
	if instance:IsA("BaseScript") then
		instance.Disabled = descriptor.disabled == true
	end
	instance:SetAttribute(OWNER_ATTRIBUTE, true)
	instance:SetAttribute(SCHEMA_ATTRIBUTE, SCHEMA_VERSION)
	instance:SetAttribute(RUNTIME_ATTRIBUTE, RUNTIME_VERSION)
	for _, childDescriptor in ipairs(descriptor.children or {}) do
		local child = instantiate(childDescriptor)
		child.Parent = instance
	end
	return instance
end

local function findTemplateChild(name)
	for _, descriptor in ipairs(RuntimeTemplate.runtimeRoot.children) do
		if descriptor.name == name then
			return descriptor
		end
	end
	error("Runtime template is missing " .. name)
end

local function findGameplayTemplateChild(name)
	local gameplayTests = findTemplateChild("GameplayTests")
	for _, descriptor in ipairs(gameplayTests.children or {}) do
		if descriptor.name == name then
			return descriptor
		end
	end
	error("Runtime template is missing GameplayTests." .. name)
end

function ProjectInitializer.initialize()
	local inspection = ProjectInitializer.inspect()
	if inspection.healthy then
		return true, "BloxQA is already initialized.", inspection
	end
	if inspection.state ~= "missing" then
		return false, "Initialization stopped because BloxQA-owned or conflicting objects already exist.", inspection
	end

	local rootClone = instantiate(RuntimeTemplate.runtimeRoot)
	local harnessClone = instantiate(RuntimeTemplate.serverHarness)
	harnessClone.Disabled = false

	local created = {}
	local ok, message = pcall(function()
		rootClone.Parent = ReplicatedStorage
		table.insert(created, rootClone)
		harnessClone.Parent = ServerScriptService
		table.insert(created, harnessClone)
	end)
	if not ok then
		for index = #created, 1, -1 do
			created[index]:Destroy()
		end
		return false, "Initialization failed and was rolled back: " .. tostring(message), ProjectInitializer.inspect()
	end

	local result = ProjectInitializer.inspect()
	return result.healthy, result.healthy and "BloxQA initialized successfully." or result.message, result
end

function ProjectInitializer.repair()
	local inspection = ProjectInitializer.inspect()
	if inspection.healthy then
		return true, "BloxQA is already healthy.", inspection
	end
	if not inspection.repairable then
		return false, "Automatic repair is unavailable because existing content would need to be replaced.", inspection
	end

	local created = {}
	local ok, message = pcall(function()
		local root = ReplicatedStorage:FindFirstChild("BloxQA")
		if not root then
			root = instantiate(RuntimeTemplate.runtimeRoot)
			root.Parent = ReplicatedStorage
			table.insert(created, root)
		else
			for name in pairs(REQUIRED_ROOT_CHILDREN) do
				if not root:FindFirstChild(name) then
					local child = instantiate(findTemplateChild(name))
					child.Parent = root
					table.insert(created, child)
				end
			end

			local gameplayTests = root:FindFirstChild("GameplayTests")
			if gameplayTests then
				for name in pairs(REQUIRED_GAMEPLAY_CHILDREN) do
					if not gameplayTests:FindFirstChild(name) then
						local child = instantiate(findGameplayTemplateChild(name))
						child.Parent = gameplayTests
						table.insert(created, child)
					end
				end
			end
		end

		if not ServerScriptService:FindFirstChild("BloxQAGameplayTestServer") then
			local harness = instantiate(RuntimeTemplate.serverHarness)
			harness.Disabled = false
			harness.Parent = ServerScriptService
			table.insert(created, harness)
		end
	end)
	if not ok then
		for index = #created, 1, -1 do
			created[index]:Destroy()
		end
		return false, "Repair failed and newly created objects were rolled back: " .. tostring(message), ProjectInitializer.inspect()
	end

	local result = ProjectInitializer.inspect()
	return result.healthy, result.healthy and "BloxQA repair completed." or result.message, result
end

function ProjectInitializer.removeOwnedRuntime()
	local root = ReplicatedStorage:FindFirstChild("BloxQA")
	local harness = ServerScriptService:FindFirstChild("BloxQAGameplayTestServer")
	for _, instance in ipairs({ root, harness }) do
		if instance and (not isOwned(instance) or instance:GetAttribute(SCHEMA_ATTRIBUTE) ~= SCHEMA_VERSION) then
			return false, "Refusing to remove unowned or unsupported BloxQA content."
		end
	end
	if harness then harness:Destroy() end
	if root then root:Destroy() end
	return true, "Owned BloxQA runtime removed."
end

ProjectInitializer.OWNER_ATTRIBUTE = OWNER_ATTRIBUTE
ProjectInitializer.SCHEMA_VERSION = SCHEMA_VERSION
ProjectInitializer.RUNTIME_VERSION = RUNTIME_VERSION

return ProjectInitializer

