local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MultiplayerCoordinator = {}
MultiplayerCoordinator.__index = MultiplayerCoordinator

local function sortedPlayers()
	local participants = Players:GetPlayers()
	table.sort(participants, function(left, right)
		if left.UserId ~= right.UserId then
			return left.UserId < right.UserId
		end
		return left.Name < right.Name
	end)
	return participants
end

function MultiplayerCoordinator.new(mode, expectedPlayers)
	local self = setmetatable({}, MultiplayerCoordinator)
	self.mode = mode
	self.expectedPlayers = expectedPlayers
	self.responses = {}

	if mode == "multiplayer" then
		local root = ReplicatedStorage:WaitForChild("BloxQA")
		local existing = root:FindFirstChild("MultiplayerBridge")
		if existing then
			existing:Destroy()
		end

		local bridge = Instance.new("RemoteEvent")
		bridge.Name = "MultiplayerBridge"
		bridge.Parent = root
		self.bridge = bridge
		self.bridgeConnection = bridge.OnServerEvent:Connect(function(player, responseType, requestId, detail)
			if responseType == "LeaveReady" or responseType == "LeaveUnavailable" then
				self.responses[requestId] = {
					player = player,
					ready = responseType == "LeaveReady",
					detail = tostring(detail or ""),
				}
			end
		end)
	end

	return self
end

function MultiplayerCoordinator:getPlayers()
	return sortedPlayers()
end

function MultiplayerCoordinator:waitForPlayerCount(count, timeoutSeconds)
	local deadline = os.clock() + timeoutSeconds
	repeat
		local participants = sortedPlayers()
		if #participants == count then
			return participants
		end
		task.wait(0.05)
	until os.clock() >= deadline

	return nil, string.format(
		"Timed out waiting for %d participant%s; observed %d",
		count,
		count == 1 and "" or "s",
		#Players:GetPlayers()
	)
end

function MultiplayerCoordinator:waitForCharacter(player, timeoutSeconds)
	local deadline = os.clock() + timeoutSeconds
	repeat
		if player.Parent ~= Players then
			return nil, "Participant left before the character became ready"
		end

		local character = player.Character
		if character
			and character:FindFirstChildOfClass("Humanoid")
			and character:FindFirstChild("HumanoidRootPart")
		then
			return character
		end
		task.wait(0.05)
	until os.clock() >= deadline

	return nil, "Participant character did not become ready before timeout"
end

function MultiplayerCoordinator:requestPlayerLeave(player, timeoutSeconds)
	if self.mode ~= "multiplayer" or not self.bridge then
		return false, "Player leave requires an active BloxQA multiplayer session"
	end
	if player.Parent ~= Players then
		return false, "Selected participant is no longer connected"
	end

	local requestId = HttpService:GenerateGUID(false)
	local removed = false
	local removingConnection = Players.PlayerRemoving:Connect(function(leavingPlayer)
		if leavingPlayer == player then
			removed = true
		end
	end)

	self.bridge:FireClient(player, "LeaveTest", requestId)
	local deadline = os.clock() + timeoutSeconds
	repeat
		if removed or player.Parent ~= Players then
			removingConnection:Disconnect()
			return true
		end

		local response = self.responses[requestId]
		if response and not response.ready then
			removingConnection:Disconnect()
			return false, response.detail ~= "" and response.detail
				or "Studio reported that this client cannot leave the test"
		end
		task.wait(0.05)
	until os.clock() >= deadline

	removingConnection:Disconnect()
	return false, "Timed out waiting for the selected participant to leave"
end

function MultiplayerCoordinator:destroy()
	if self.bridgeConnection then
		self.bridgeConnection:Disconnect()
		self.bridgeConnection = nil
	end
	if self.bridge then
		self.bridge:Destroy()
		self.bridge = nil
	end
end

return MultiplayerCoordinator
