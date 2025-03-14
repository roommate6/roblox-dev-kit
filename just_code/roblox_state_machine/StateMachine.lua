local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")

local State = require(script.Classes.State)
local Transition = require(script.Classes.Transition)
local Signal = require(script.Vendor.Signal)
local Trove = require(script.Vendor.Trove)
local Copy = require(script.Functions.deepCopy)

type Trove = Trove.Trove

local DUPLICATE_ERROR: string = "There cannot be more than 1 state by the same name"
local DATA_WARNING: string = "[Warning]: The data of this state machine is not a table. It will be converted to a table. Please do not set data to a non table object"
local STATE_NOT_FOUND: string = "Attempt to %s, but there is no state by the name of %s"
local WRONG_TRANSITION: string = "Attempt to add a transition that is not a transition"

-- Used for quicker access to the directories
local cacheDirectories = {} :: {[Instance]: {any}}

--[=[
    @class StateMachine

    State Machines consist of state managers that dictate at which state does an object currently meet at.
    It allows us to easily manage what should an object do at each given state and when/how it should change
    between them
]=]
local StateMachine = {}
StateMachine.__index = StateMachine
--[=[
    @prop Data {[string]: any}
    @within StateMachine

    Contains the data that is shared across all states and transitions of this state machine. Should be accessed with :GetData

    E.g
    ```lua
    local stateMachine = RobloxStateMachine.new("state", states, {health = 0})
    stateMachine:GetData().health = 50
    ```

    The data is shared across all states and transitions. It can be access in 2 different ways

    ```lua
    --transition.lua
    local GoToBlue = Transition.new("Blue")

    function GoToBlue:OnDataChanged(data)
        print(self.Data, data) -- 2 ways to access the data
        return false
    end

    --state.lua
    local Default: State = State.new("Blue")

    function Default:OnInit(data)
        print(self.Data, data)
    end
    ```
]=]
StateMachine.Data = {} :: {[string]: any}
--[=[
    @prop StateChanged⚡ Signal<(string, string)>?
    @within StateMachine

    Called whenever the state of this state machine changes. The first argument
    is the new state and the second one is the previous state. If there was no previous state
    then it will be an empty string

    e.g
    ```lua
    exampleStateMachine.StateChanged:Connect(function(newState: string, previousState: string)
        print("Our previous state was: " .. previousState .. " now our state is: " .. newState)
    end)
    ```
]=]
StateMachine.StateChanged = nil :: Signal.Signal<(string, string)>?
--[=[
    @prop DataChanged⚡ Signal<({[string]: any}, any, any, any)>?
    @within StateMachine

    Called whenever the data from the state machine gets changed. 

    :::warning
    **DataChanged** only gets called when the data is changed by a **ChangeData** call
    :::

    e.g
    ```lua
    exampleStateMachine.DataChanged:Connect(function(data: {[string]: any}, index: any, newValue: any, oldValue: any)
        print("Changed the index " .. index .. " with: ", newValue)
    end)
    ```
]=]
StateMachine.DataChanged = nil :: Signal.Signal<({[string]: any}, any, any, any)>?
--[=[
    @prop State State
    @within StateMachine

    A reference to the State class
]=]
StateMachine.State = State
--[=[
    @prop Transition Transition
    @within StateMachine

    A reference to the Transition class
]=]
StateMachine.Transition = Transition
--[=[
    @prop _States {[string]: State}
    @within StateMachine
    @private

    Caches the states of this state machine. It's used to change states and check transitions
]=]
StateMachine._States = {} :: {[string]: State}
--[=[
    @prop _trove Trove
    @within StateMachine
    @private

    A trove object to store and clear up connections
]=]
StateMachine._trove = newproxy() :: Trove
--[=[
    @prop _stateTrove Trove
    @within StateMachine
    @private

    A trove object to clear state threads and connections
]=]
StateMachine._stateTrove = newproxy() :: Trove
--[=[
    @prop _CurrentState string
    @within StateMachine
    @private

    Caches the current state in a string format. It's used to fire the StateChanged signal
]=]
StateMachine._CurrentState = "" :: string
--[=[
    @prop _PreviousState string
    @within StateMachine
    @private

    Caches the previous state in a string format. It's used to fire the StateChanged signal
]=]
StateMachine._PreviousState = "" :: string
--[=[
    @prop _Destroyed boolean
    @within StateMachine
    @private

    Checks if the object has already been destroyed or not
]=]
StateMachine._Destroyed = false :: boolean
--[=[
    Used to create a new State Machine. It expects 3 arguments being the third one an optional one

    ```lua
    local ReplicatedStorage = game:GetService("ReplicatedStorage")

    local RobloxStateMachine = require(ReplicatedStorage.RobloxStateMachine)

    local exampleStateMachine: RobloxStateMachine.RobloxStateMachine = RobloxStateMachine.new(
        "Default",
        RobloxStateMachine:LoadDirectory(script.Example.States), 
        {
            part = workspace.Example,
            time = tick(),
        }
    )
    ```

    @param initialState string -- The name of the State at which it should start
    @param states {State.State} -- An array of the states this State machine should have
    @param initialData {[string]: any}? -- The starting data to be used by the states

    @return RobloxStateMachine
]=]
function StateMachine.new(initialState: string, states: {State}, initialData: {[string]: any}?): RobloxStateMachine
    local self = setmetatable({}, StateMachine)

    self._States = {} :: {[string]: State}
    self._trove = Trove.new()
    self._stateTrove = Trove.new()

    self._Destroyed = false
    
    self.Data = initialData or {} :: {[string]: any}
    self.StateChanged = Signal.new() :: Signal.Signal<(string, string)>
    self.DataChanged = Signal.new() :: Signal.Signal<({[string]: any}, any, any, any)>?

    -- Load all the states
    for _, state: State.State in states do
        if self._States[state.Name] then
            error(DUPLICATE_ERROR.." \""..state.Name.."\"", 2)
        end

        -- Create a copy of the State "parented" to this StateMachine
        local stateClone: State.State = Copy(state)
        stateClone.Data = self.Data

        -- Fill up the necessary "parent" accessing methods with our methods 
        stateClone._changeState = function(newState: string)
            self:ChangeState(newState)
        end
        stateClone._changeData = function(index: string, newValue: any)
            self:ChangeData(index, newValue)
        end
        stateClone._getState = function()
            return self:GetCurrentState()
        end
        stateClone._getPreviousState = function()
            return self:GetPreviousState()
        end

        -- Load all the Transitions
        stateClone._transitions = {}
        for _, transition: Transition in stateClone.Transitions do
            if #transition.Name == 0 then -- (Transitions don't need names, but must have one for HashTable)
                transition.Name = HttpService:GenerateGUID(false)
            end

            -- Create a copy of the Transition "parented" to this StateMachine
            local transitionClone: Transition = Copy(transition)

            if transitionClone.Type ~= Transition.Type then -- (must be a Transition)
                error(WRONG_TRANSITION, 2)
            end
            
            -- Fill up the necessary "parent" accessing methods with our methods 
            transitionClone.Data = stateClone.Data
            transitionClone._changeData = function(index: string, newValue: any)
                self:ChangeData(index, newValue)
            end
            transitionClone._getState = function()
                return self:GetCurrentState()
            end
            transitionClone._getPreviousState = function()
                return self:GetPreviousState()
            end
            transitionClone._changeState = function(newState: string)
                self:ChangeState(newState)
            end

            -- Add the Transition to the list of initialized Transitions
            stateClone._transitions[transitionClone.Name] = transitionClone

            -- Run its own initialization method and add it to be cleaned up on destruction
            task.spawn(transitionClone.OnInit, transitionClone, self.Data)
            self._trove:Add(transitionClone, "OnDestroy")
        end

        -- Add the State to the list of initialized States
        self._States[state.Name] = stateClone

        -- Run its own initialization method and add it to be cleaned up on destruction
        task.spawn(stateClone.OnInit, stateClone, self.Data)
        self._trove:Add(stateClone, "OnDestroy")
    end

    if not self._States[initialState] then -- (Make sure the staring State is valid)
        error(STATE_NOT_FOUND:format("create a state machine", initialState), 2)
    end

    local previousState: State = nil
    self._trove:Connect(RunService.Heartbeat, function(deltaTime: number)
        if self._Destroyed then -- (Don't run if destroyed)
            return
        end

        self:_CheckTransitions()
        
        local state = self:_GetCurrentStateObject()

        -- Skip the first frame of a State change
        local firstFrame: boolean = state ~= previousState
        previousState = state
        if firstFrame then
            return
        end

        -- Don't run if nothing was changed
        if not state or getmetatable(state).OnHeartbeat == state.OnHeartbeat then
            return
        end

        -- Run the heartbeat method for the state
        self:_CallMethod(state, false, "OnHeartbeat", self:GetData(), deltaTime)
    end)

    -- Add the Events to be cleaned on destruction
    self._trove:Add(self.StateChanged)
    self._trove:Add(self.DataChanged)

    -- Start on the starting state
    self:_ChangeState(initialState)

    return self
end

--[=[
    Returns the current state of the State Machine (in string form)

    ```lua
    local exampleStateMachine = RobloxStateMachine.new("Default", {}, {})
    print(exampleStateMachine:GetCurrentState()) -- Default
    ```

    @return string
]=]
function StateMachine:GetCurrentState(): string
    return self._CurrentState
end

--[=[
    Returns the previous state of the State Machine (in string form)

    ```lua
    local exampleStateMachine = RobloxStateMachine.new("Default", {...BlueStateHere}, {})
    exampleStateMachine:ChangeState("Blue")
    print(exampleStateMachine:GetPreviousState()) -- "Default"
    ```

    @return string
]=]
function StateMachine:GetPreviousState(): string
    return self._PreviousState
end

--[=[
    Changing the custom data, while firing **DataChanged** Event
    
    (You can also just use **GetData** and change the data at runtime, _**However** this dose not fire **DataChanged** event!_)

    ```lua
    local stateMachine = RobloxStateMachine.new("state", states, {health = 0})

    stateMachine:GetData().health = 50 -- This is the same as
    stateMachine:ChangeData("Health", 50) -- this
    ```

    @param index string
    @param newValue any

    @return ()
]=]
function StateMachine:ChangeData(index: string, newValue: any): ()
    if self._Destroyed or self.Data[index] == newValue then
        return
    end
    
    -- Change the data
    local oldValue: any = self.Data[index]
    self.Data[index] = newValue

    local state: State = self:_GetCurrentStateObject()
    
    -- Call DataChanged Events
    self:_CallMethod(state, false, "OnDataChanged", self.Data, index, newValue, oldValue)
    self.DataChanged:Fire(self.Data, index, newValue, oldValue)
end

--[=[
    Gets the custom data of this state machine

    ```lua
    local stateMachine = RobloxStateMachine.new("Start", {state1, state2}, {health = 20})

    print(stateMachine:GetData().health) -- 20
    ```

    @return {[string]: any}
]=]
function StateMachine:GetData(): {[string]: any}
    -- Clear the data if it is not a table
    if typeof(self.Data) ~= "table" then
        warn(DATA_WARNING)
        self.Data = {}
    end

    return self.Data
end

--[=[
    Used to load thru an entire directory (and its sub-directories).
    
    _**(Especially useful to load states and or transitions!)**_

    ```lua
    local exampleStateMachine: RobloxStateMachine.RobloxStateMachine = RobloxStateMachine.new(
        "Default",
        RobloxStateMachine:LoadDirectory(script.Example.States), 
        {
            part = workspace.Example,
            time = tick(),
        }
    )
    ```

    (You can also use it to load specific files by feeding the names you wish to load)


    @param directory Instance
    @param names {string}? -- If you wish to only load specific states you can pass an array of names

    @return {any}
]=]
function StateMachine:LoadDirectory(directory: Instance, names: {string}?): {any}
    -- Load from scratch if not already loaded in the past
    if not cacheDirectories[directory] then
        cacheDirectories[directory] = {}

        for _, child: Instance in directory:GetDescendants() do
            if not child:IsA("ModuleScript") then
                continue
            end
            
            -- Load the ModuleScript
            local success: boolean, result: any = pcall(function()
                return require(child)
            end)

            -- Make sure it's actually a table
            if 
                not success or
                typeof(result) ~= "table"
            then
                continue
            end

            -- Make sure its a valid State or Transition
            if result.Type ~= State.Type and result.Type ~= Transition.Type then
                continue
            end

            -- Use the name of the Script if no name found
            if not result.Name or result.Name == "" then
                result.Name = child.Name
            end
            
            -- Save the result to be loaded quickly in the future
            table.insert(cacheDirectories[directory], result)
        end
    end

    -- If there is nothing left to do, then return the saved Modules
    if not names then
        return cacheDirectories[directory]
    end

    -- Only return the modules with the same name as in `names`
    local filteredFiles = {}
    for _, file in cacheDirectories[directory] do
        if table.find(names, file.Name) then
            table.insert(filteredFiles, file)
        end
    end

    return filteredFiles
end

--[=[
    Clears all the memory used by the state machine

    (Use if you wish to stop using the state machine at any point)

    ```lua
    local stateMachine = RobloxStateMachine.new(...)

    task.wait(5)

    stateMachine:Destroy()
    ```

    @return ()
]=]
function StateMachine:Destroy(): ()
    if self._Destroyed then
        return
    end
    
    self._Destroyed = true
    
    -- Run the Leave method on the State before destroying
    local state: State? = self:_GetCurrentStateObject()
    if state then
        task.spawn(state.OnLeave, state, self:GetData())
    end

    -- Clean up everything to save memory
    self._trove:Destroy()
    self._stateTrove:Destroy()
end

--[=[
    Changes the current state of our state machine to a new one.

    _(**currentState:CanChangeState** must be satisfied before it can change!)_

    @param newState string -- The name of the new state

    @return ()
]=]
function StateMachine:ChangeState(newState: string): ()
    --Make sure we are allowed to change states
    local currentState: State? = self:_GetCurrentStateObject()
    if currentState and not currentState:CanChangeState(newState) then
        return
    end

    self:_ChangeState(newState)
end

--[=[
    Checks if the state exists

    @private

    @param stateName string

    @return boolean
]=]
function StateMachine:_StateExists(stateName: string): boolean
    return self._States[stateName] ~= nil
end

--[=[
    Called to _truly_ change the current state of the state machine

    @private

    @param newState string

    @return ()
]=]
function StateMachine:_ChangeState(newState: string): ()
    if self._Destroyed then
        return
    end
    
    -- Make sure the State even exists to begin with
    assert(self:_StateExists(newState), STATE_NOT_FOUND:format(`change to {newState}`, newState))

    -- Only swap if it's not the same
    if self._CurrentState == newState then
        return
    end

    -- Get the updated State classes
    local previousState: State? = self:_GetCurrentStateObject()
    local state: State? = self._States[newState]

    if not state then
        return
    end

    -- Clean up the previous state
    if previousState then
        task.spawn(previousState.OnLeave, previousState, self:GetData())
        self:_CallTransitions(previousState, "OnLeave", self:GetData())
    end
    self._stateTrove:Clean()

    -- Switch to the new state
    task.defer(function()
        self:_CallTransitions(state, "OnEnter", self:GetData())
    end)
    self:_CallMethod(state, true, "OnEnter", self:GetData())
    
    -- Update the current state
    self._CurrentState = newState

    -- Fire StateChanged Event
    if previousState then
        self._PreviousState = previousState.Name
        self.StateChanged:Fire(newState, previousState.Name or "")
    end
end

--[=[
    Gets the current state object of the state machine

    @private

    @return State
]=]
function StateMachine:_GetCurrentStateObject(): State?
    return self._States[self:GetCurrentState()]
end

--[=[
    Checks if we meet any condition to change the current state.
    
    The first transition to return true then will change the current state

    @private

    @return ()
]=]
function StateMachine:_CheckTransitions(): ()
    -- Check every Transition for a possible State change (prioritizing the first found)
    for _, transition: Transition in self:_GetCurrentStateObject()._transitions do
        if transition:CanChangeState(self:GetData()) and transition:OnDataChanged(self:GetData()) then
            self:ChangeState(transition.TargetState)
            break
        end
    end
end

--[=[
    Calls the transition method of the given state

    @param state State
    @param methodName string
    @param ... any

    @private

    @return ()
]=]
function StateMachine:_CallTransitions(state: State, methodName: string, ...: any): ()
    -- Call the method for each Transition
    for _, transition: Transition in state._transitions do
        task.spawn(transition[methodName], transition, ...)
    end
end

--[=[
    Calls the corresponding method for the given state. (to be cleaned up later)

    @param state State
    @param methodName string
    @param shouldDefer boolean?
    @param ... any

    @private

    @return ()
]=]
function StateMachine:_CallMethod(state: State, shouldDefer: boolean, methodName: string, ...: any): ()    
    local action = shouldDefer and "defer" or "spawn"
    
    self._stateTrove:Add(
        task[action](state[methodName], state, ...)
    )
end
export type RobloxStateMachine = typeof(StateMachine)
export type State = State.State
export type Transition = Transition.Transition

return setmetatable(StateMachine, {
    __call = function(_, initialState: string, states: {State}, initialData: {[string]: any}?): RobloxStateMachine
        return StateMachine.new(initialState, states, initialData)
    end
})