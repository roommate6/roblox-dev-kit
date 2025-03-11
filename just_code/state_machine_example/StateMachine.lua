-- Module Script

export type State = {
	Name: string,
	Duration: number,
	Enter: (string) -> (boolean),
	Started: () -> (),
	Completed: () -> (string),
}
type StoredState = {
	Duration: number,
	Enter: (string) -> (boolean),
	Started: () -> (),
	Completed: () -> (),
}

local StateMachine = {}
StateMachine.__index = StateMachine

function StateMachine.new()
	local self = setmetatable({
		States = {},
		CurrentStateName = nil,

		_startTime = 0,
	}, StateMachine)

	return self
end

function StateMachine:DefineStates(states: {State})
	if #states < 2 then
		warn("You must define at least two states.")
		return
	end

	for _, state in ipairs(states) do
		self.States[state.Name] = {
			Duration = state.Duration,
			Enter = state.Enter,
			Started = state.Started,
			Completed = state.Completed,
		}
	end

	self.CurrentStateName = states[1].Name 
end

function StateMachine:GoTo(nextStateName: string)
	if not self.CurrentStateName then
		warn("No states has been defined yet.")
		return
	end

	local nextState: StoredState = self.States[nextStateName]
	if not nextState then
		warn("The state " .. nextStateName .. " does not exist.")
		return
	end

	local canPerform = true
	if nextState.Enter then
		canPerform = nextState.Enter(self.CurrentStateName)
	end

	if not canPerform then
		return
	end

	self.CurrentStateName = nextStateName
	self._startTime = workspace:GetServerTimeNow()

	if nextState.Started then
		nextState.Started()
	end
end

function StateMachine:Update()
	if self.CurrentStateName == nil then return end
	
	local duration = self.States[self.CurrentStateName].Duration
	if duration == 0 then return end

	local deltaTime = workspace:GetServerTimeNow() - self._startTime
	if deltaTime < duration then return end

	local currentState: State = self.States[self.CurrentStateName]
	if not currentState.Completed then
		self:GoTo(self.CurrentStateName)
		return
	end
	
	local nextStateName = currentState.Completed()
	if not self.States[nextStateName] then
		warn("The state " .. nextStateName .. " does not exist.")
		self:GoTo(self.CurrentStateName)
		return
	end
	
	self:GoTo(nextStateName)
end

return StateMachine
