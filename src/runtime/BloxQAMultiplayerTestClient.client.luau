local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StudioTestService = game:GetService("StudioTestService")

if not RunService:IsStudio() then
	return
end

local root = ReplicatedStorage:WaitForChild("BloxQA", 30)
if not root then
	return
end

local bridge = root:WaitForChild("MultiplayerBridge", 30)
if not bridge or not bridge:IsA("RemoteEvent") then
	return
end

bridge.OnClientEvent:Connect(function(command, requestId)
	if command ~= "LeaveTest" then
		return
	end

	local canCheck, canLeave = pcall(function()
		return StudioTestService:CanLeaveTest()
	end)
	if not canCheck or not canLeave then
		bridge:FireServer(
			"LeaveUnavailable",
			requestId,
			canCheck and "Studio reported that this client cannot leave the test"
				or "Could not check whether this client can leave the test"
		)
		return
	end

	bridge:FireServer("LeaveReady", requestId)
	task.defer(function()
		local ok, message = pcall(function()
			StudioTestService:LeaveTest()
		end)
		if not ok then
			warn("[BloxQA] Client failed to leave multiplayer test: " .. tostring(message))
		end
	end)
end)
