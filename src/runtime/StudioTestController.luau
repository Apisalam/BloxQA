local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StudioTestService = game:GetService("StudioTestService")

local root = ReplicatedStorage:WaitForChild("BloxQA")
local TestRegistry = require(root:WaitForChild("TestRegistry"))
local gameplayTests = root:WaitForChild("GameplayTests")

local StudioTestController = {}

local function failedReport(testName, message, durationMs, mode, expectedPlayers)
	return {
		total = 1,
		passed = 0,
		failed = 1,
		results = {
			{
				name = testName,
				mode = mode or "singleplayer",
				expectedPlayers = expectedPlayers or 1,
				status = "FAIL",
				passed = false,
				errorMessage = message,
				durationMs = durationMs,
			},
		},
	}
end

function StudioTestController.run(testId, options)
	options = options or {}

	local testDefinition, lookupError = TestRegistry.findById(testId, gameplayTests)
	if not testDefinition then
		return failedReport(tostring(testId), lookupError, 0)
	end
	local mode = testDefinition.mode
	local expectedPlayers = testDefinition.players

	local startedAt = os.clock()
	local ok, result = pcall(function()
		local args = {
			protocol = "BloxQA",
			protocolVersion = 2,
			testId = testDefinition.id,
			timeoutSeconds = options.timeoutSeconds or testDefinition.timeout,
			mode = mode,
			expectedPlayers = expectedPlayers,
		}
		if mode == "multiplayer" then
			return StudioTestService:ExecuteMultiplayerTestAsync(expectedPlayers, args)
		end
		return StudioTestService:ExecutePlayModeAsync(args)
	end)
	local durationMs = math.max(0, math.floor((os.clock() - startedAt) * 1000 + 0.5))

	if not ok then
		return failedReport(
			testDefinition.name,
			"Could not run Studio playtest: " .. tostring(result),
			durationMs,
			mode,
			expectedPlayers
		)
	end

	if type(result) ~= "table" or type(result.results) ~= "table" then
		return failedReport(
			testDefinition.name,
			"StudioTestService returned an invalid result",
			durationMs,
			mode,
			expectedPlayers
		)
	end

	return result
end

return StudioTestController
