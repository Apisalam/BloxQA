return {
	id = "PlayerLeave",
	name = "Player Leave Test",
	category = "Multiplayer",
	description = "Verifies that one simulated client can leave while the other remains active.",
	timeout = 25,
	mode = "multiplayer",
	players = 2,

	run = function(ctx)
		local participants, participantError = ctx:getParticipants()
		ctx:expect(participants ~= nil, participantError)

		for _, participant in ipairs(participants) do
			local character, characterError = ctx:waitForCharacter(participant)
			ctx:expect(character ~= nil, characterError)
		end

		local departed, leaveError = ctx:requestPlayerLeave(participants[2], 10)
		ctx:expect(departed, leaveError)

		local remaining, remainingError = ctx:waitForParticipantCount(1, 5)
		ctx:expect(remaining ~= nil, remainingError)
		local character, characterError = ctx:waitForCharacter(remaining[1], 5)
		ctx:expect(character ~= nil, characterError)
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		ctx:expect(humanoid and humanoid.Health > 0, "Remaining participant was not alive after the leave")

		ctx:log("One simulated participant left and one remained active")
		return true
	end,
}
