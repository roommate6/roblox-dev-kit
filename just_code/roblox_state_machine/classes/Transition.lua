local mergeTables = require(script.Parent.Parent.Functions.mergeTables)

--[=[
    @class Transition

    Dictates how and when should you move between different states
]=]
local Transition = {}
Transition.__index = Transition
Transition.Type = "Transition"
--[=[
    @prop Name string
    @within Transition

    The name of the transition. This is used to identify this transition. _(Not required)_

    ```lua
    local Transition = StateMachine.Transition

    local GoToBlue = Transition.new("Blue")
    GoToBlue.Name = "GoToBlue"
    ```
]=]
Transition.Name = "" :: string
--[=[
    @prop TargetState string
    @within Transition

    The name of the state to change to when transitioning. (Usually set while creating the transition)

    ```lua
    local Transition = StateMachine.Transition

    local GoToBlue = Transition.new("Blue") -- The target state is now "Blue"
    print(GoToBlue.TargetState) -- "Blue"
    ```
]=]
Transition.TargetState = "" :: string
--[=[
    @prop Data {[string]: any}
    @within Transition

    Contains the custom state machine data. It can be accessed from within the class

    ```lua
    local Default: State = Transition.new("Blue")

    function Default:OnInit(data)
        print(self.Data)
    end
    ```
]=]
Transition.Data = {} :: {[string]: any}
--[=[
    @prop _changeState (newState: string)->()?
    @within Transition
    @private

    Gets the current state of our state machine. (This is set by the state machine itself)
]=]
Transition._changeState = nil :: (newState: string)->()?
--[=[
    @prop _changeData (index: string, newValue: any)->()?
    @within Transition
    @private

    This is used to change the custom data of the state machine. (This is set by the state machine itself)
]=]
Transition._changeData = nil :: (index: string, newValue: any)-> ()?
--[=[
    @prop _getState (index: string, newValue: any)-> string
    @within Transition
    @private

    Gets the current state of our state machine. (This is set by the state machine itself)
]=]
Transition._getState = nil :: (index: string, newValue: any)-> string
--[=[
    @prop _getPreviousState ()-> string?
    @within Transition
    @private

    Gets the previous state of our state machine. (This is set by the state machine itself)
]=]
Transition._getPreviousState = nil :: ()-> string?

--[=[
    Creates a new transition.
    
    Transitions are used to tell our state when and how should it move from the 
    current state to a different one. They are meant to be reusable and allow us
    to easily add and reuse transitions between states and objects.

    ```lua
    local ReplicatedStorage = game:GetService("ReplicatedStorage")

    local StateMachine = require(ReplicatedStorage.RobloxStateMachine)
    local Transition = StateMachine.Transition

    local GoToBlue = Transition.new("Blue")
    GoToBlue.OnHeartbeat = false

    function GoToBlue:OnDataChanged(data)
        return tick() - data.time > 10 -- Will change to blue after 10 seconds 
    end

    return GoToBlue
    ```

    @param targetState string? -- The state the transition will change to when it meets the requirements

    @return Transition
]=]
function Transition.new(targetState: string?): Transition
    local self = setmetatable({}, Transition)
    self.TargetState = targetState or ""

    return self
end

--[=[
    Extends a state, inheriting the behavior from the parent state

    ```lua
    local transition = Transition.new("Blue")
    
    function transition:Print()
        print("Hello World!")
    end

    local extendedTransition = transition:Extend("Red")

    function extendedTransition:OnInit()
        self:Print() -- Will print "Hello World!"
    end
    ```

    @param targetState string

    @return Transition
]=]
function Transition:Extend(targetState: string): Transition
    return mergeTables(Transition.new(targetState), self)
end

--[=[
    :::info
    This is a **Virtual Method**. Virtual Methods are meant to be overwritten
    :::

    Called whenever a state machine is newly created with this transition

    ```lua
    function Transition:OnInit()
        print("Hello World")
    end
    ```

    @param _data {[string]: any} -- This is the custom data from the parent StateMachine

    @return ()
]=]
function Transition:OnInit(_data: {[string]: any}): ()
    
end

--[=[
    :::info
    This is a **Virtual Method**. Virtual Methods are meant to be overwritten
    :::

    Called whenever you first enter this transition object

    ```lua
    function State:OnEnter(data)
        data.part.Color = Color3.fromRGB(0, 166, 255)
    end
    ```

    @param _data {[string]: any} -- This is the custom data from the parent StateMachine

    @return ()
]=]
function Transition:OnEnter(_data: {[string]: any}): ()

end

--[=[
    :::info
    This is a **Virtual Method**. Virtual Methods are meant to be overwritten
    :::

    Called whenever your about leave this transition. _(and before **OnDestroy**)_

    ```lua
    function State:OnLeave(data)
        data.stuff:Clean()
    end
    ```

    @param _data {[string]: any} -- This is the custom data from the parent StateMachine

    @return ()
]=]
function Transition:OnLeave(_data: {[string]: any}): ()

end


--[=[
    :::info
    This is a **Virtual Method**. Virtual Methods are meant to be overwritten
    :::

    @deprecated v1.1.7 -- This function is redundant since it essentially just works as a blocker for OnDataChanged

    Whether it can change to this state or not. It's a good way to lock the current state

    @param data {[string]: any}

    @return boolean -- By default it returns true
]=]
function Transition:CanChangeState(data: {[string]: any}): boolean
    assert(data, "")
    return true
end

--[=[
    Changes the current state of our state machine to a new one.

    @param newState string -- The name of the new state

    @return ()
]=]
function Transition:ChangeState(newState: string): ()
    if not self._changeState then
        return
    end

    -- Call the "parent" StateMachine Method
    self._changeState(newState)
end

--[=[
    :::info
    This is a **Virtual Method**. Virtual Methods are meant to be overwritten
    :::
    
    Determines wether the transition should should change yet.

    Should return true if it should change to the target state
    and false if it shouldn't

    @param data {[string]: any}

    @return boolean -- By default it returns false
]=]
function Transition:OnDataChanged(data: {[string]: any}): boolean
    assert(data, "")
    return false
end

--[=[
    Gets the current state of our state machine

    @return string
]=]
function Transition:GetState(): string
    if not self._getState then
        return ""
    end

    -- Call the "parent" StateMachine Method
    return self._getState()
end

--[=[
    Gets the previous state of our state machine

    @return string
]=]
function Transition:GetPreviousState(): string
    if not self._getPreviousState then
        return ""
    end

    -- Call the "parent" StateMachine Method
    return self._getPreviousState()
end

--[=[
    Changing the custom data, while firing **DataChanged** Event
    
    (You can also just use the date argument and change the data at runtime, _**However** this dose not fire **DataChanged** event!_)

    ```lua
    local example: State = State.new("Blue")

    function example:OnEnter(data)
        self:ChangeData("color", Color3.fromRGB(255, 0, 0)) -- Change to red :D

        data.part.Color = data.color
    end
    ```

    @param index string
    @param newValue any

    @return ()
]=]
function Transition:ChangeData(index: string, newValue: any): ()
    if not self._changeData then
        return
    end

    -- Call the "parent" StateMachine Method
    self._changeData(index, newValue)
end

--[=[
    :::info
    This is a **Virtual Method**. Virtual Methods are meant to be overwritten
    :::

    Called whenever the state machine is being destroyed

    ```lua
    function Transition:OnDestroy()
        print("I was destroyed!")
    end
    ```

    @return ()
]=]
function Transition:OnDestroy(): ()
    
end

export type Transition = typeof(Transition)

return setmetatable(Transition, {
    __call = function(_, properties): Transition
        return Transition.new(properties)
    end
})