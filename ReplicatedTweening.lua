--[[Created by SteadyOn

	THIS MODULE MUST BE IN REPLICATEDSTORAGE - YOU NEED TO REQUIRE THIS MODULE SOMEWHERE ON THE CLIENT:
	require(game.ReplicatedStorage.ReplicatedTweening)
	
	Documentation:
	
	:GetTweenObject(instance [Instance], TweenInfo [TweenInfo Object], PropertyTable [Table])
	Parameters are exactly the same as TweenService:Create(), it returns a fake Tween object with Play, Pause and Stop functions.
	
	Tween:Play(Yield [Boolean, optional], Player [Player Object, optional]) - Tween being the object returned by GetTweenObject
	Runs the tween. The player parameter will only play the tween for that specific player. The Yield parameter specifies whether
	the function should yield until the tween has completed or not.
	
	Tween:Stop(Player [Player Object, optional]) - Tween being the object returned by GetTweenObject
	Stops the tween. The player parameter will only stop the tween for that specific player.
	
	Tween:Pause(Player [Player Object, optional]) - Tween being the object returned by GetTweenObject
	Pauses the tween. The player parameter will only pause the tween for that specific player.
	
	Tutorial:
	
	To set up, you just need to put 'require(game.ReplicatedStorage.ReplicatedTweening)' somewhere in a LocalScript, if you don't have
	one yet, just create a new one. Also make sure to put this module into ReplicatedStorage.
	
	To use this module, first require it (e.g. require(game.ReplicatedStorage.ReplicatedTweening)). To get the tween object you must
	first call :GetTweenObject(), this returns a fake Tween object. Use this object to play, stop and pause the tween by using
	Play(), Stop(), Pause() as functions of the Tween object (e.g. Tween:Play()). You can also enter a player as the first parameter
	of each of these functions to stop, play or pause the tween only for that specific player.
	
	Example code:
	local CustomTweenService = require(game.ReplicatedStorage.ReplicatedTweening)
	local tweenInfo = TweenInfo.new(2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	
	local tween = CustomTweenService:GetTweenObject(game.Workspace.Part, tweenInfo, {CFrame = CFrame.new(Vector3.new(0,0,0))})
	tween:Play()
--]]

local module = {}
local tService = game:GetService("TweenService")
local rService = game:GetService("RunService")
local tEvent
if tEvent == nil and rService:IsServer() then
	tEvent = Instance.new("RemoteEvent", script)
	tEvent.Name = "TweenEvent"
else
	tEvent = script:WaitForChild("TweenEvent")
end


function TweenInfo_To_Table(tInfo)
	local info = {}
	info[1] = tInfo.Time or 1 
	info[2] = tInfo.EasingStyle or Enum.EasingStyle.Quad
	info[3] = tInfo.EasingDirection or Enum.EasingDirection.Out
	info[4] = tInfo.RepeatCount or 0
	info[5] = tInfo.Reverses or false
	info[6] = tInfo.DelayTime or 0
	return info
end

function Table_To_TweenInfo(tbl)
	local tInfo = TweenInfo.new(tbl[1], tbl[2], tbl[3], tbl[4], tbl[5], tbl[6])
	return tInfo
end

function serverAssignProperties(instance, properties)
	print("Assigning properties")
	for property, value in pairs (properties) do
		print("Assigned",property,"to",value)
		instance[property] = value
	end
end

function module:GetTweenObject(instance, tInfo, propertyTable)
	local tweenMaster = {}
	tweenMaster.DontUpdate = {} -- table of specific players that it stopped for part way.
	tInfo = TweenInfo_To_Table(tInfo)
	function tweenMaster:Play(Yield, SpecificClient)
		tweenMaster.Paused = false
		if SpecificClient == nil then
			tEvent:FireAllClients("RunTween", instance, tInfo, propertyTable)
		else
			tEvent:FireClient("RunTween", instance, tInfo, propertyTable)
		end
		if Yield then
			local i = 0
			repeat wait(1) i = i + 1 until i ==  tInfo[1] or tweenMaster.Stopped
			if tweenMaster.Paused == nil or tweenMaster.Paused == false then
				serverAssignProperties(instance, propertyTable) -- assign the properties server side
			end
			return
		else
			spawn(function()
				local i = 0
				repeat wait(1) i = i + 1 until i == tInfo[1] or tweenMaster.Stopped
				if tweenMaster.Paused == nil or tweenMaster.Paused == false then
					serverAssignProperties(instance, propertyTable) -- assign the properties server side
				end
			end)
		end
	end
	function tweenMaster:Pause(SpecificClient)
		if SpecificClient == nil then
			tweenMaster.Paused = true
			tEvent:FireAllClients("PauseTween", instance)
		else
			table.insert(tweenMaster.DontUpdate, SpecificClient)
			tEvent:FireClient("PauseTween", instance)
		end
	end
	function tweenMaster:Stop(SpecificClient)
		if SpecificClient == nil then
			tweenMaster.Stopped = true
			tEvent:FireAllClients("StopTween", instance)
		else
			tEvent:FireClient("StopTween", instance)
		end
	end
	return tweenMaster
end


if rService:IsClient() then -- OnClientEvent only works clientside
	local runningTweens = {}
	tEvent.OnClientEvent:Connect(function(purpose, instance, tInfo, propertyTable)
			if tInfo ~= nil then
				tInfo = Table_To_TweenInfo(tInfo)
			end
			
			if purpose == "RunTween" then
				if runningTweens[instance] ~= nil then -- im aware this will pick up paused tweens, however it doesn't matter
					runningTweens[instance]:Cancel() -- stop previously running tween to run this one
					warn("Canceled a previously running tween to run requested tween")
				end
				
				local tween = tService:Create(instance, tInfo, propertyTable)
				runningTweens[instance] = tween
				tween:Play()
				wait(tInfo.Time or 1)
				if runningTweens[instance] == tween then -- make sure it hasn't changed to a different tween
					runningTweens[instance] = nil -- remove to save memory
				end
			elseif purpose == "StopTween" then
				if runningTweens[instance] ~= nil then -- check that the tween exists
					runningTweens[instance]:Stop() -- stop the tween
					runningTweens[instance] = nil -- delete from table
				else
					warn("Tween being stopped does not exist.")
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

return module
