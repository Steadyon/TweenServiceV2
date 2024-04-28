-- V.2.2

--[[Created by SteadyOn

	THIS MODULE MUST BE IN REPLICATEDSTORAGE - YOU NEED TO REQUIRE THIS MODULE SOMEWHERE ON THE CLIENT:
	require(game.ReplicatedStorage.ReplicatedTweening)

	Documentation:

	:Create(instance [Instance], TweenInfo [TweenInfo Object], PropertyTable [Table]) [Tween]
	Parameters are exactly the same as TweenService:Create(), it returns a fake Tween object with Play,
	Pause and Stop functions.

	Tween:Play(Yield [Boolean, optional], Player [Player Object, optional])
	Runs the tween. The player parameter will only play the tween for that specific player.
	The Yield parameter specifies whether the function should yield until the tween has completed or not.
	
	Tween:QueuePlay(Yield [Boolean, optional], Player [Player Object, optional]) - Add the tween to a tween queue which will start
	playing the queue automatically immediately after the previous tween on that instance completes. Behaves exactly the same way as 
	Tween:Play() once started, except the initial firing of the tween is managed on the client. For this reason, best practice is to
	fire this event as close to when you would like it to be played on the client to maintain alignment between tweens. If fired 
	multiple times in a short time frame, this may result in clients becoming out of sync over time.

	Tween:Stop(Player [Player Object, optional])
	Stops the tween. The player parameter will only stop the tween for that specific player.

	Tween:Pause(Player [Player Object, optional])
	Pauses the tween. The player parameter will only pause the tween for that specific player.
	

	Tutorial:

	To set up, you just need to put 'require(game.ReplicatedStorage.ReplicatedTweening)' somewhere in
	a LocalScript, if you don't have one yet, just create a new one. Also make sure to put this module
	into ReplicatedStorage.

	To use this module, first require it (e.g. require(game.ReplicatedStorage.ReplicatedTweening)).
	To get the tween object you must first call :GetTweenObject(), this returns a fake Tween object.
	Use this object to play, stop and pause the tween by using Play(), Stop(), Pause()
	as functions of the Tween object (e.g. Tween:Play()).

	You can also enter a player as the first parameter of each of these functions
	to stop, play or pause the tween only for that specific player.

	Example code:
	local CustomTweenService = require(game.ReplicatedStorage.ReplicatedTweening)
	local tweenInfo = TweenInfo.new(2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

	local tween = CustomTweenService:Create(game.Workspace.Part, tweenInfo, {CFrame = CFrame.new(Vector3.new(0,0,0))})
	tween:Play()
--]]

local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local TweenEvent = script:WaitForChild("TweenEvent", 5)
local HttpService = game:GetService("HttpService")

local TweenModule = {}
local latestFinish = {} -- this table operates on both the client and the server, server side it only stores GLOBAL tweens, local side it stores every local tween.

--| if there is no tween event, it will be created and parented to the script.
if TweenEvent == nil and RunService:IsServer() then
	TweenEvent = Instance.new("RemoteEvent")
	TweenEvent.Name = "TweenEvent"
	TweenEvent.Parent = script
end

--| Converting TweenInfo to an array is needed to pass it through the remote event:
local function TweenInfo_To_Table(tInfo: TweenInfo)
	local info = {}
	info[1] = tInfo.Time or 1 
	info[2] = tInfo.EasingStyle or Enum.EasingStyle.Quad
	info[3] = tInfo.EasingDirection or Enum.EasingDirection.Out
	info[4] = tInfo.RepeatCount or 0
	info[5] = tInfo.Reverses or false
	info[6] = tInfo.DelayTime or 0
	return info
end

--| When the TweenInfo array is received on the client, we will need to convert it back to TweenInfo:
local function Table_To_TweenInfo(tbl)
	return TweenInfo.new(unpack(tbl))
end

--| Will change server properties for the targetted instances after client tweens are done:
local function serverAssignProperties(instance: Instance, properties: {[string]: any})
	--print("Assigning server properties..")
	for property, value in pairs (properties) do
		--print(string.format("Assigned %s to %s", property, tostring(value)))
		instance[property] = value
	end
end

local function getInstanceCurrentSimulatedState(instance: Instance, properties : {[any]: any})
	local state = {}
	for property, _  in pairs(properties) do
		state[property] = instance[property]
	end
	return state
end

function TweenModule:Create(instance: Instance, tInfo: TweenInfo, propertyTable: {[string]: any}, SimulateServerTween: boolean?)
	local tweenMaster = {}
	tweenMaster.DontUpdate = {} -- table of specific players that it stopped for part way.
    tweenMaster._SafeTweenInfo = tInfo
	tweenMaster._TweenID = HttpService:GenerateGUID(false)
	tweenMaster.HasFinished = false
	tInfo = TweenInfo_To_Table(tInfo)


	if SimulateServerTween then
		tweenMaster._SimulateTween = true
        
        -- / Create a copy of the instance in Script.SimulatedTweensFolder
        local SimulatedTweensFolder = script:FindFirstChild("SimulatedTweensFolder")
        if not SimulatedTweensFolder then
            SimulatedTweensFolder = Instance.new("Folder")
            SimulatedTweensFolder.Name = "SimulatedTweensFolder"
            SimulatedTweensFolder.Parent = script
        end

        tweenMaster.SimulatedInstance = instance:Clone()
        tweenMaster.SimulatedInstance.Parent = SimulatedTweensFolder

        tweenMaster.SimulatedTween = TweenService:Create(tweenMaster.SimulatedInstance, tweenMaster._SafeTweenInfo, propertyTable)
	end

	local function Play(Yield, SpecificClient, Queue) -- this is on it's own as it needs to be called by both QueuePlay and Play 
		local waitTime = tInfo[1] * (tInfo[4] ~= 0 and tInfo[4] or 1) * (tInfo[5] and 2 or 1)
		local finishTime = os.time() + waitTime

		latestFinish[instance] = latestFinish[instance] or os.time() -- cannot be nil.
		Queue = Queue or false
		tweenMaster.Paused = false

		if SpecificClient == nil and not Queue then
			latestFinish[instance] = finishTime -- adds an entry to array with finish time of this tween (used for queueing)
			TweenEvent:FireAllClients("RunTween", instance, tInfo, propertyTable, tweenMaster._TweenID, nil, tick())
		elseif Queue and SpecificClient == nil then -- deal with queued tweens
			waitTime = waitTime + (latestFinish[instance] - os.time())
			latestFinish[instance] = finishTime + (latestFinish[instance] - os.time()) -- adds an entry to array with finish time of this tween (used for queueing)
			TweenEvent:FireAllClients("QueueTween", instance, tInfo, propertyTable, tweenMaster._TweenID, nil, tick())
		elseif Queue and SpecificClient then
			TweenEvent:FireClient(SpecificClient, "QueueTween", instance, tInfo, propertyTable, tweenMaster._TweenID, nil, tick()) -- queue tween for specific player
		elseif SpecificClient then
			TweenEvent:FireClient(SpecificClient, "RunTween", instance, tInfo, propertyTable, tweenMaster._TweenID, nil, tick()) -- play tween for specific player
		end

		if tweenMaster._SimulateTween then
			-- / Run the tween on the simulated instance
			tweenMaster.SimulatedTween:Play()

            tweenMaster._PauseSimulatedTween = function()
                tweenMaster.SimulatedTween:Pause()
            end

            tweenMaster._StopSimulatedTween = function()
                tweenMaster.SimulatedTween:Cancel()
            end

            tweenMaster._ResumeSimulatedTween = function()
                tweenMaster.SimulatedTween:Play()
            end

			task.spawn(function() -- Clear up the simulated instance after the tween has completed
				tweenMaster.SimulatedTween.Completed:Wait()
				tweenMaster.SimulatedInstance:Destroy()
			end)
		end

		if Yield and SpecificClient == nil then
			local i, existingFinish = 0, latestFinish[instance]
			repeat task.wait(0.05) i = i + 0.05 until i >= waitTime or tweenMaster.Stopped
			
			if latestFinish[instance] == existingFinish then
				latestFinish[instance] = nil -- clear memory if this instance hasn't already been retweened.
			end
			if tweenMaster.Paused == nil or tweenMaster.Paused == false then
				serverAssignProperties(instance, propertyTable) -- assign the properties server side
				tweenMaster.HasFinished = true
			end
			
		elseif SpecificClient == nil then
			task.spawn(function()
				local i, existingFinish = 0, latestFinish[instance]
				repeat task.wait(0.05) i = i + 0.05 until i >= waitTime or tweenMaster.Stopped
				
				if latestFinish[instance] == existingFinish then
					latestFinish[instance] = nil -- clear memory if this instance hasn't already been retweened.
				end
				if tweenMaster.Paused == nil or tweenMaster.Paused == false then
					serverAssignProperties(instance, propertyTable) -- assign the properties server side
					tweenMaster.HasFinished = true
				end
			end)
		end
	end

	function tweenMaster:Play(Yield, SpecificClient)
		Play(Yield, SpecificClient)

        if tweenMaster._SimulateTween then
            tweenMaster._ResumeSimulatedTween()
        end
	end

	function tweenMaster:QueuePlay(Yield, SpecificClient)
		Play(Yield, SpecificClient, true)
	end

	function tweenMaster:Pause(SpecificClient)
		if tweenMaster._SimulateTween then
			tweenMaster._CurrentExpectedState = getInstanceCurrentSimulatedState(tweenMaster.SimulatedInstance, propertyTable)
		end

		if SpecificClient == nil then
			tweenMaster.Paused = true
			TweenEvent:FireAllClients("PauseTween", instance, nil, nil, tweenMaster._TweenID, tweenMaster._CurrentExpectedState, tick())
		else
			table.insert(tweenMaster.DontUpdate, SpecificClient)
			TweenEvent:FireClient(SpecificClient, "PauseTween", instance, nil, nil,  tweenMaster._TweenID, tweenMaster._CurrentExpectedState, tick())
		end

        if tweenMaster._SimulateTween then
            tweenMaster._PauseSimulatedTween()
        end
	end

	function tweenMaster:Stop(SpecificClient)
		if tweenMaster._SimulateTween then
			tweenMaster._CurrentExpectedState = getInstanceCurrentSimulatedState(tweenMaster.SimulatedInstance, propertyTable)
		end

		if SpecificClient == nil then
			tweenMaster.Stopped = true
			TweenEvent:FireAllClients("StopTween", instance, nil, nil,  tweenMaster._TweenID, tweenMaster._CurrentExpectedState, tick())
		else
			TweenEvent:FireClient(SpecificClient, "StopTween", instance, nil, nil,  tweenMaster._TweenID, tweenMaster._CurrentExpectedState, tick())
		end

        if tweenMaster._SimulateTween then
            tweenMaster._StopSimulatedTween()
        end
	end
	return tweenMaster
end


if RunService:IsClient() then -- OnClientEvent only works clientside
	local runningTweens = {}

	local runningTweensById = {}
	TweenEvent.OnClientEvent:Connect(function(purpose, instance, tInfo, propertyTable, tweenID, expectedProperties, expectedStartTime)
		if tInfo ~= nil then
			tInfo = Table_To_TweenInfo(tInfo)
		end

		if expectedProperties then
			serverAssignProperties(instance, expectedProperties)
		end

		local shortenBy = 0
		if expectedStartTime and tInfo then
			shortenBy = tick() - expectedStartTime

			-- Recreate TweenInfo with the shortened time
			tInfo = TweenInfo.new(tInfo.Time - shortenBy, tInfo.EasingStyle, tInfo.EasingDirection, tInfo.RepeatCount, tInfo.Reverses, tInfo.DelayTime)
		end

		local function runTween(queued)
			local finishTime = os.time() + tInfo.Time
			latestFinish[instance] = latestFinish[instance] or os.time() -- cannot be nil.

			local existingFinish = latestFinish[instance]
			if queued and latestFinish[instance] >= os.time() then
				local waitTime = (latestFinish[instance] - os.time())
				latestFinish[instance] = finishTime + waitTime
				existingFinish = latestFinish[instance]
				task.wait(waitTime)
			else
				latestFinish[instance] = finishTime
			end


			if runningTweens[instance] ~= nil and runningTweens[instance].PlaybackState ~= Enum.PlaybackState.Paused and runningTweensById[instance] ~= tweenID then -- im aware this will pick up paused tweens, however it doesn't matter (it did matter, i've fixed it now)
				runningTweens[instance]:Cancel() -- stop previously running tween to run this one
				warn(string.format('Cancelled a previously running tween for instance "%s" tor run a new requested one.', instance.Name))
			end

			runningTweensById[instance] = tweenID
			local tween = TweenService:Create(instance, tInfo, propertyTable)
			runningTweens[instance] = tween
			tween:Play()
			
			--print("TweenStarted",os.time(),existingFinish)
			tween.Completed:Wait()
			--print("TweenComplete",os.time(),existingFinish)
			if latestFinish[instance] == existingFinish then
				latestFinish[instance] = nil -- clear memory if this instance hasn't already been retweened.
			end
			
			if runningTweens[instance] == tween then -- make sure it hasn't changed to a different tween
				runningTweens[instance] = nil -- remove to save memory
			end
		end

		if purpose == "RunTween" then
			runTween()
		elseif purpose == "QueueTween" then
			runTween(true) -- run as a queued tween
		elseif purpose == "StopTween" then
			if runningTweens[instance] ~= nil then -- check that the tween exists
				runningTweens[instance]:Cancel() -- stop the tween
				runningTweens[instance] = nil -- delete from table
			else
				warn("Tween being stopped does not exist or the instance itself.")
			end
		elseif purpose == "PauseTween" then
			if runningTweens[instance] ~= nil then -- check that the tween exists
				runningTweens[instance]:Pause() -- pause the tween
			else
				warn("Tween being paused does not exist.")
			end
		end
	end)
end

return TweenModule
