

local StateMachine = require(
	game:GetService("ReplicatedStorage")
		:WaitForChild("StateMachine")
)
local RunService = game:GetService("RunService")
local Tool = script.Parent

local stateMachine = StateMachine.new()

local states: {StateMachine.State} = {
	{
		Name = "Idle",
		Duration = 0,
	},
	{
		Name = "Cooldown",
		Duration = 3,
		Enter = function(oldState: string)
			return oldState == "Idle"
		end,
		Started = function()
			Tool.Handle.BrickColor = BrickColor.random()
		end,
		Completed = function()
			return "Idle"
		end
	}
}

stateMachine:DefineStates(states)

RunService.Stepped:Connect(function()
	stateMachine:Update()
	print(stateMachine.CurrentStateName)
end)

Tool.Activated:Connect(function()
	stateMachine:GoTo("Cooldown")
end)