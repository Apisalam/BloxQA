local StudioTestService = game:GetService("StudioTestService")

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
	local testName = options.testName or tostring(testId)
	local timeoutSeconds = options.timeoutSeconds or 10
	local mode = options.mode or "singleplayer"
	local expectedPlayers = options.players or 1

	if type(testId) ~= "string" or testId == "" then
		return failedReport(testName, "A valid discovered test ID is required", 0, mode, expectedPlayers)
	end
	if mode ~= "singleplayer" and mode ~= "multiplayer" then
		return failedReport(testName, "Unsupported test mode: " .. tostring(mode), 0, mode, expectedPlayers)
	end
	if mode == "multiplayer"
		and (type(expectedPlayers) ~= "number"
			or expectedPlayers % 1 ~= 0
			or expectedPlayers < 2
			or expectedPlayers > 8)
	then
		return failedReport(testName, "Multiplayer tests require 2 to 8 players", 0, mode, expectedPlayers)
	end

	local startedAt = os.clock()
	local ok, result = pcall(function()
		local args = {
			protocol = "BloxQA",
			protocolVersion = 2,
			testId = testId,
			timeoutSeconds = timeoutSeconds,
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
			testName,
			"Could not run Studio playtest: " .. tostring(result),
			durationMs,
			mode,
			expectedPlayers
		)
	end

	if type(result) ~= "table" or type(result.results) ~= "table" then
		return failedReport(
			testName,
			"StudioTestService returned an invalid result. Is the BloxQA per-place runtime installed?",
			durationMs,
			mode,
			expectedPlayers
		)
	end

	return result
end

return StudioTestController
