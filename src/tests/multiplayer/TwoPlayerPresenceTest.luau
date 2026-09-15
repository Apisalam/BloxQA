return {
	id = "TwoPlayerPresence",
	name = "Two Player Presence Test",
	category = "Multiplayer",
	description = "Verifies that two simulated players join with ready characters.",
	timeout = 20,
	mode = "multiplayer",
	players = 2,

	run = function(ctx)
		local participants, participantError = ctx:getParticipants()
		ctx:expect(participants ~= nil, participantError)
		ctx:expect(#participants == 2, "Expected exactly two simulated participants")
		ctx:expect(participants[1] ~= participants[2], "Expected two distinct Player instances")

		local characters = {}
		for index, participant in ipairs(participants) do
			ctx:expect(participant.Parent ~= nil, "Participant " .. index .. " is not connected")
			local character, characterError = ctx:waitForCharacter(participant)
			ctx:expect(character ~= nil, characterError)
			characters[index] = character

			local humanoid = character:FindFirstChildOfClass("Humanoid")
			ctx:expect(humanoid ~= nil, "Participant " .. index .. " character is missing a Humanoid")
			ctx:expect(humanoid.Health > 0, "Participant " .. index .. " Humanoid is not alive")
			ctx:expect(
				character:FindFirstChild("HumanoidRootPart") ~= nil,
				"Participant " .. index .. " character is missing HumanoidRootPart"
			)
		end
		ctx:expect(characters[1] ~= characters[2], "Expected two distinct Character instances")

		task.wait(1)
		for index, participant in ipairs(participants) do
			ctx:expect(participant.Parent ~= nil, "Participant " .. index .. " left during the assertion window")
			ctx:expect(participant.Character == characters[index], "Participant " .. index .. " character changed during the assertion window")
			local humanoid = characters[index]:FindFirstChildOfClass("Humanoid")
			ctx:expect(humanoid and humanoid.Health > 0, "Participant " .. index .. " did not remain alive")
			ctx:expect(
				characters[index]:FindFirstChild("HumanoidRootPart") ~= nil,
				"Participant " .. index .. " lost HumanoidRootPart during the assertion window"
			)
		end

		ctx:log("Two simulated participants joined with ready characters")
		return true
	end,
}
