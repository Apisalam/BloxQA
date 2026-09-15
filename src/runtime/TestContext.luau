local Players = game:GetService("Players")

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
	return self:waitFor(function()
		return Players:GetPlayers()[1]
	end, timeoutSeconds)
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

return TestContext

