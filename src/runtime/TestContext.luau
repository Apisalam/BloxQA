local MultiplayerCoordinator = require(script.Parent:WaitForChild("MultiplayerCoordinator"))

local TestContext = {}
TestContext.__index = TestContext

function TestContext.new(args, testDefinition)
	local self = setmetatable({}, TestContext)
	for key, value in pairs(args or {}) do
		self[key] = value
	end
	self.testId = testDefinition.id
	self.testName = testDefinition.name
	self.timeout = testDefinition.timeout
	self.timeoutSeconds = tonumber(self.timeoutSeconds) or testDefinition.timeout
	self.mode = testDefinition.mode or "singleplayer"
	self.expectedPlayers = self.mode == "multiplayer" and testDefinition.players or 1
	self.multiplayer = MultiplayerCoordinator.new(self.mode, self.expectedPlayers)
	return self
end

function TestContext:waitFor(predicate, timeoutSeconds, intervalSeconds)
	local timeout = timeoutSeconds or self.timeout
	local interval = intervalSeconds or 0.05
	local deadline = os.clock() + timeout

	repeat
		local ok, value = pcall(predicate)
		if ok and value then
			return value
		end
		task.wait(interval)
	until os.clock() >= deadline

	return nil
end

function TestContext:getPlayer(timeoutSeconds)
	local participants = self.multiplayer:waitForPlayerCount(
		self.expectedPlayers,
		timeoutSeconds or self.timeout
	)
	return participants and participants[1] or nil
end

function TestContext:getParticipants(timeoutSeconds)
	return self.multiplayer:waitForPlayerCount(
		self.expectedPlayers,
		timeoutSeconds or self.timeout
	)
end

function TestContext:waitForParticipantCount(count, timeoutSeconds)
	return self.multiplayer:waitForPlayerCount(count, timeoutSeconds or self.timeout)
end

function TestContext:waitForCharacter(player, timeoutSeconds)
	return self.multiplayer:waitForCharacter(player, timeoutSeconds or self.timeout)
end

function TestContext:requestPlayerLeave(player, timeoutSeconds)
	return self.multiplayer:requestPlayerLeave(player, timeoutSeconds or self.timeout)
end

function TestContext:expect(condition, message)
	if not condition then
		error(message or "Expectation failed", 2)
	end
	return condition
end

function TestContext:fail(message)
	error(message or "Test failed", 2)
end

function TestContext:log(message)
	print(string.format("[BloxQA][%s] %s", self.testId, tostring(message)))
end

function TestContext:cleanup()
	if self.multiplayer then
		self.multiplayer:destroy()
		self.multiplayer = nil
	end
end

return TestContext
