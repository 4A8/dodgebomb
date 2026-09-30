-- Discord: rusked; roblox: rusk3d

-- A bomb dodging minigame with 2 modes
local ReplicatedStorage = game:GetService("ReplicatedStorage") -- the replicated storage service
local plr = game:GetService("Players").LocalPlayer -- local player
local char = plr.Character or plr.CharacterAdded:Wait() -- Wait until the character is loaded
local hum = char:WaitForChild("Humanoid") -- the humanoid
local button = game.Workspace.ButtonStand:WaitForChild("Button") -- the button that will be used for activating the game
local buttoncf = button.CFrame -- the button's cframe, so it can return to it's original position
local buttoncol = button.Color -- its color, same as before
local buttonDownDepth = button.Size.X * 0.47 -- how deep the button should be pressed
local buttonDown = buttoncf * CFrame.new(-buttonDownDepth, 0, 0) -- the position of the button when it's pressed 
local buttonPressed = false -- so it can check without having to be based on whetehr or not the position is exactly the original or exactly buttondown
local launching = false -- to check if the minigame is started
local tickSound = ReplicatedStorage.Tick -- the ticking sound that will be used for the jenga mode
local tower = game.Workspace:WaitForChild("Tower") -- the tower for the jenga mode
local menu = plr.PlayerGui:WaitForChild("GUI"):WaitForChild("Menu") -- the menu where the player picks the mode
local rsv = game:GetService("RunService")
local Debris = game:GetService("Debris")
local twn = game:GetService("TweenService")
local soundsv = game:GetService("SoundService")
local uisv = game:GetService("UserInputService")

local activeObst = {} -- used later for the :Deflect() method
local explObstacle = {} -- used for the class (I decided to implement it this way mainly because deflecting the obstacle later would be much easier)
explObstacle.__index = explObstacle -- read explObstacle when it's called
local meshes = ReplicatedStorage.Meshes:GetChildren() -- the meshes that the obstacle cna have
function explObstacle.new() -- create the obstacle
	local self = setmetatable({}, explObstacle) -- set the metatable to make it a class
	self.obj = Instance.new("Part") -- create the part
	self.obj.Size = Vector3.new(4,4,4)
	self.obj.Anchored = true
	self.obj.CanCollide = false
	self.obj.Parent = game.Workspace:WaitForChild("Obstacles")
	self.obj.Name = "Obstacle" -- and set all of its properties

	activeObst[self.obj] = self -- add it as an active obstacle so it can be deflected later

	self.mesh = meshes[math.random(1,#meshes)] -- pick a mesh from the folder
	self.mesh = self.mesh:Clone() 
	self.mesh.Parent = self.obj -- clone it into the part

	self.movingConnect = nil -- to disconnect later
	self.rotateConnect = nil -- same as above

	return self -- return the class' properties
end




local options = {-1,1} -- pick between negative and positive
local function picksign()
	local option = options[math.random(1,#options)]
	return option
end

local function bezier(subj, dur, P0, P1, P2, completed: () -> ()) -- bezier curve for the obstacle and later on the craters
	local t = 0 -- elapsed time
	local connect -- so it cna be disconnected later and passed to explObstacle.movingConnect

	connect = rsv.PreRender:Connect(function(dtr) -- run every frame
		t += math.clamp(dtr / dur, 0, 1) -- add the amount of time elapsed to t and divide it by the duration so that it gets added slower/faster and meet the intended duration
		if t >= 1 then -- if the duration is completed
			connect:Disconnect() -- disconnect the event
			connect = nil -- and set it to nil to clean it up
			if completed then -- if the user passed a completion function
				completed() -- execute it
			end
		end

		local pos = (1 - t)^2 * P0 + 2 * (1 - t) * t * P1 + t^2 * P2 -- set position variable to the result of the quadratic bezier curve formula
		subj.Position = pos -- and set the position to the variab;e
	end)
	return connect -- again used for .movingConnect
end

local function rotate(subj, dur, rot) -- rotate a part to give it a more realistic launching look
	local t = 0 -- same as before
	local connect -- ^
	connect = rsv.PreSimulation:Connect(function(dtr)
		t += math.clamp(dtr / dur, 0, 1)
		if t >= 1 then
			connect:Disconnect()
			connect = nil
		end

		subj.CFrame *= CFrame.Angles(math.rad(rot),math.rad(rot),math.rad(rot)) -- multiply the current CFrame by a new CFrame that has the rotation

	end)
	return connect -- used for explObstacle.rotateConnect so it can be disconnected later
end


function explObstacle:Launch(origin, target, dur, impactFunc: () -> ()) -- method to launch the obstacle to target
	local halfway = origin:Lerp(target, 0.5) + Vector3.new(0,75,0) -- lerp the halfway point which will be P1 and add 75 studs to its height to make it actually curve

	self.movingConnect = bezier(self.obj, dur, origin, halfway, target, function() -- launch the object and set finally set movingConnect to the connection so it can be disconnected later
		twn:Create(self.obj,TweenInfo.new(0.25,Enum.EasingStyle.Quad), {Transparency = 1, Size = self.obj.Size * 2}):Play() -- make the object fade out on impact
		if impactFunc then
			impactFunc() -- again, run a function on completion/impact if one has been proivded
		end
		if not self.obj.Parent then return end -- return if the obj has no parent (if the player clicked the button to stop launching or died and destroyed it)
		self.obj.Parent = game.Workspace.Inactive -- move it to an inactive folder to not interfere with the :Deflect() method later
		task.wait(0.5) -- wait a little before destroying so the explosion can have its effect
		activeObst[self.obj] = nil -- remove it from the activeObst table
		self.obj:Destroy() -- then destroy
	end)
	self.rotateConnect = rotate(self.obj, dur, 5) -- rotate while launching for the aforementioned effect
end


local function canvasRange(canvas: BasePart) -- to pick a random position within a part
	local x = canvas.Position.X + math.random((canvas.Size.X/2)*-1,canvas.Size.X/2) -- the minimum is the position of the part with negative of half its size and half positive as its maximum
	local y = canvas.Position.Y + math.random((canvas.Size.Y/2)*-1,canvas.Size.Y/2) -- for each axis
	local z = canvas.Position.Z + math.random((canvas.Size.Z/2)*-1,canvas.Size.Z/2)
	return {x,y,z} -- reutrn the results
end

local function canvasSides(canvas: BasePart) -- pick one of the sides of a part, used for the crater function so that the debris goes all the way
	local x = canvas.Position.X + canvas.Size.X/2*picksign() -- run the pick sign function so it's, in this instance, the leftmost or rightmost position of the part
	local y = canvas.Position.Y + canvas.Size.Y/2*picksign()
	local z = canvas.Position.Z + canvas.Size.Z/2*picksign()

	return {x,y,z} -- and return its results
end


function explObstacle:Deflect() -- method to deflect the obstacle
	self.obj.Parent = game.Workspace.Inactive -- move it to inactive so that the method can be used again after a new obstacle is launched
	local positions = canvasRange(game.Workspace.EvilWall.Deflection) -- deflect it to a position somewhere around the evil wall
	self.movingConnect:Disconnect() -- disconnect the previous launch which was towards the player
	self.rotateConnect:Disconnect() -- disconnect the rotation as well
	self.movingConnect = nil
	self.rotateConnect = nil
	self:Launch(self.obj.Position, Vector3.new(positions[1], positions[2], positions[3]), 1) -- then launch it to its new position after it has been deflected
end


local craterPositions -- used to disconnect later when it stops launching
local function crater(subj: BasePart, amount, timeToLand) -- make a crater when subj hits something, with `amount` of debris, and the debris lands in timeToLand
	local col
	local mat -- will be the color and material of the part it hit
	local subjSize = subj.Size -- the size of the subj that hits something
	subj.Anchored = false -- so .Touched can be triggered
	local alreadyRan = false -- so it doesn't create a crater each time .touched is triggered
	craterPositions = subj.Touched:Connect(function(other) -- when the subject hits its target
		if not alreadyRan then -- if it hasn't ran already
			alreadyRan = true -- set it to true
			col = other.Color -- inherit the properties of what has been hit
			mat = other.Material
			local canvas = Instance.new("Part") -- where the debris will land
			canvas.Size = subj.Size + Vector3.new(12,-3.5,12) -- scale to how big the object that hit something was
			canvas.Position = Vector3.new(subj.Position.X,other.Position.Y+other.Size.Y/2,subj.Position.Z) -- set the position to where the subject hit but the Y to the top of what has been hit
			canvas.Name = "Canvas" 
			canvas.Parent = game.Workspace -- parent to workspace so the part actually has a use
			canvas.Anchored = true -- anchor it so it doesn't get moved by the explosion or smth
			canvas.Transparency = 1 -- make it invisible
			canvas.CanCollide = false -- and uncollideable since it's just there to dictate where the debris will land
			for i = 1, amount, 1 do -- for every time the amount of debris needed isn't met create one piece
				task.wait() -- so the computer doesn't explode by trying to run eveyrthing at once
				local e = Instance.new("Part") -- create the debris
				e.Position = canvas.Position -- set its position to where the canvas was made
				e.Size = subjSize/2 -- scale it with the thing that hit something and make it half the size
				e.Material = mat
				e.Color = col -- and make the debris match the object that was hit
				e.Parent = game.Workspace

				local canvr = canvasRange(canvas)
				local canvs = canvasSides(canvas)
				local positionz = {
					Vector3.new(canvr[1],canvas.Position.Y,canvs[3]), -- either goes to a random position on one of the canvas' X axis edges
					Vector3.new(canvs[1],canvas.Position.Y,canvr[3]) -- or to a random position on a Z axis edge
				}
				local pos = positionz[math.random(1,2)] -- pick one of them
				bezier(e, timeToLand, canvas.Position, (canvas.Position+pos)/2+Vector3.new(0,25,0), pos) -- bezier curve the debris to their target positions
				rotate(e, timeToLand, 4) -- and rotate it (but a little more slightly)
				task.delay(timeToLand,function() -- fade out the debris 0.25s after landing without yielding
					twn:Create(e, TweenInfo.new(0.25, Enum.EasingStyle.Quad), {Transparency = 1}):Play()
				end)
				Debris:AddItem(e,timeToLand+0.25) -- and destroy the debris after it's faded out
			end
			canvas:Destroy() -- destroy the canvas since it's not used anymore
		end
	end)
end

local evw = game.Workspace:WaitForChild("EvilWall") -- the wall where the obstacles are launched from 

local plrWon -- used for the jenga mode
local baseplateLava -- same as above
local function startLaunching(target,timeToHit) -- start launching the bombs or whatever
	if target == nil or timeToHit == nil then return end -- if any of the parameters were omitted, return
	local target0 = target -- will be used to differentiate between the varying target posiitons, for example the player moving or the different blocks of the jenga tower
	if target0 == "jenga" then -- the target is set to this when the player activates jenga mode
		plrWon = false -- set the plrWon variable to tell when the player has won
		baseplateLava = game.Workspace.Baseplate.Touched:Connect(function(otherPart) -- connect to the baseplate's touch event to kill the player if they fall off the tower
			if otherPart.Parent:FindFirstChild("Humanoid") and not plrWon then -- if what touched the baseplate is a player and the player hasn't won yet
				otherPart.Parent:FindFirstChild("Humanoid").Health = 0 -- kill them
			end
		end)
	end
	launching = true -- set launching to true
	while launching == true do -- while launching
		task.wait(timeToHit) -- wait before launching the first obstacle so the player can prepare or something; and obviously wait between further obstacle launches
		if target0 == "jenga" then -- if jenga mode is active
			local towerChildren = tower:GetChildren() -- get the blocks of the tower
			local blockKey = math.random(1,#towerChildren) -- pick a random block
			target = towerChildren[blockKey].Position -- the target is one of the tower's blocks
		end
		if typeof(target0) == "Instance" and target0:IsA("BasePart") then -- if the target provided is a part
			target = target0.Position -- set the target to the target's position
			if target0.Name == "HumanoidRootPart" then target = target0.Position-Vector3.new(0,5,0) end -- or if it's a humanoidrootpart, set the target to it but 5 studs down
		end
		if launching ~= true then break end -- if launching has been stopped in the meantime then break
		local range = canvasRange(evw) -- the range of the evil wall, so the range objects will be thrown from within
		local origin = Vector3.new(range[1],range[2],evw.Position.Z) -- construct the vector 3 with the position within the range gotten, but keep Z since it doesn't make a difference anyways

		local obstacleMeta = explObstacle.new() -- the obstacle's class
		local obstacle = obstacleMeta.obj -- the actual object that will be used externally
		obstacleMeta:Launch(origin, target, timeToHit, function() -- launch the obstacle
			local expl = Instance.new("Explosion") -- make an explosion on completion
			expl.Parent = obstacle -- parent it to the obstacle
			if target0 == "jenga" then -- if jenga mode is active
				expl.BlastPressure = 5000000 -- make the explosion stronger so it can have more of an effect on the tower
			else
				expl.BlastPressure = 500000 -- otherwise just have it as the default
			end
			expl.Position = obstacle.Position -- set the explosion to be where the obstacle is
			crater(obstacle, 5, 0.5) -- and make the crater
		end)
	end
end

local emerged = false -- the tower is not emerged
local function disappear() -- to make the tower collapse or disappear on the player's death or win
	if emerged then -- only run if the tower is emerged already
		emerged = false -- no longer emerged
		for _,e in ipairs(tower:GetChildren()) do -- for every part of the tower
			task.wait()
			e.Anchored = true -- anchor it
			e.CanCollide = false -- and turn off the collisions since it will be moved a little bit erratically
			twn:Create(e, TweenInfo.new(1, Enum.EasingStyle.Back, Enum.EasingDirection.In), {Position = Vector3.new(e.Position.X, -100, e.Position.Z), Transparency = 1}):Play() -- move it under the map with a cool effect
			Debris:AddItem(e, 1.05) -- destroy it afterwards
		end
	end
end

local function stopLaunching() -- to stop launching the obstacles or bombs
	if launching == true then -- only run if they're being launched
		launching = false -- no longer being launched
		local obstacleFolder = game.Workspace:FindFirstChild("Obstacles")
		if obstacleFolder and obstacleFolder:GetChildren()[1] ~= nil then -- if there is an obstacle in the folder 
			for _,e in ipairs(game.Workspace.Obstacles:GetChildren()) do -- for each one of them
				activeObst[e].movingConnect:Disconnect() -- disconnect the moving connection
				activeObst[e].rotateConnect:Disconnect() -- and the rotation connection
				activeObst[e].movingConnect = nil -- and set it to nil
				activeObst[e].rotateConnect = nil -- and this
				activeObst[e] = nil -- set this to nil as well to clean up the table
				e:Destroy() -- destroy them
			end
		end
	end
	if plrWon == false then -- if plrWon is false, meaning that the jenga mode has been initialized to set it
		plrWon = true -- set it to true
	end
	if craterPositions ~= nil then -- if the craterPositions connection exists
		craterPositions:Disconnect() -- disconnect
		craterPositions = nil -- and clean it
	end
	if baseplateLava ~= nil then -- if baseplateLava is connected
		baseplateLava:Disconnect() -- disconnect it
		baseplateLava = nil -- and set it to nil
	end
	twn:Create(button,TweenInfo.new(0.5, Enum.EasingStyle.Quad), {CFrame = buttoncf, Color = buttoncol}):Play() -- and tween the button to its original psoition
	buttonPressed = false -- and change the variable so it can be checked
end

local function emerge() -- the tower emerging function
	if not emerged then -- if it's not emerged already
		emerged = true -- set it to true
		local children = ReplicatedStorage.Tower:GetChildren() -- the blocks in the tower
		table.sort(children, function(a, b)
			return a.Position.Y < b.Position.Y -- sort the blocks by their Y position since the tower will be built block by block from the ground up
		end)
		for _, e: BasePart in ipairs(children) do -- for each block in the table that is now sorted
			local clonedBlock = e:Clone() -- clone it
			clonedBlock.Parent = tower -- and add it to the tower model
			twn:Create(clonedBlock, TweenInfo.new(0.1, Enum.EasingStyle.Quad), {Transparency = 0}):Play() -- tween it to be opaque
			soundsv:PlayLocalSound(ReplicatedStorage.Brick) -- and play a brick sound
			task.wait(0.1)
		end

	end
end

local timerGui = plr.PlayerGui.GUI.Timer
menu.List.Buttons.Normal.MouseButton1Click:Connect(function() -- when the normal mode button is clicked
	menu.Visible = false -- hide the menu
	task.spawn(startLaunching, char:WaitForChild("HumanoidRootPart"), 1.5) -- and start the launching, using task.spawn since we donțt want it to yield
end)
menu.List.Buttons.Jenga.MouseButton1Click:Connect(function() -- when the jenga mode button is clicked
	menu.Visible = false -- hide
	emerge() -- build the tower
	char.HumanoidRootPart.CFrame = CFrame.new(tower.Part6.CFrame.Position + Vector3.new(0,tower.Part6.Size.Y/2,0)) -- and teleport the player on top of it
	task.wait(0.05)
	task.spawn(startLaunching, "jenga", 0.9) -- start launching, but faster since the bombs are a little less dangerous in this mode
	timerGui.Visible = true -- display the timer
	tickSound.Volume = 0.5 -- enable the tick sound
	for i = 15, 0, -1 do -- for each second above 15
		if char.Humanoid:GetState() == Enum.HumanoidStateType.Dead then -- if the player is dead
			return -- stop the function
		end
		timerGui.Text = tostring(i) -- display the current time left
		soundsv:PlayLocalSound(tickSound) -- play the sound
		task.wait(1) -- and wait a second
	end
	timerGui.Visible = false -- after the time is up, hide the itmer
	stopLaunching() -- stop launching, which will also set plrWon to true
	disappear() -- make the tower disappear
	soundsv:PlayLocalSound(ReplicatedStorage.Victory) -- and play a win sound
end)
menu.Close.MouseButton1Click:Connect(function() -- when the close button is clicked
	menu.Visible = false -- hide the menu
	stopLaunching() -- just moves the button back
end)

local debounce = false -- debounce to prevent spamming
button.ClickDetector.MouseClick:Connect(function() -- when the button is clicked
	if not debounce then -- if the debounce is not active
		debounce = true -- activate it
		soundsv:PlayLocalSound(ReplicatedStorage.Button) -- play a button sound
		if not buttonPressed then -- if the button is not pressed
			buttonPressed = true -- set the variable to true
			twn:Create(button, TweenInfo.new(0.5, Enum.EasingStyle.Quad), {CFrame = buttonDown, Color = Color3.fromRGB(196, 40, 28)}):Play() -- and move it down and make it red
		end
		if launching == false then -- if the game is not already running
			menu.Visible = true -- show the menu so the player can start it
		else
			stopLaunching() -- otherwise stop it
		end
		task.wait(0.5) -- wait 0.5s before deactivating the debounce
		debounce = false
	end
end)

uisv.InputBegan:Connect(function(input, gpe) -- when an input begins
	if input.KeyCode == Enum.KeyCode.F and not gpe then -- and it's the F key
		local obstacle = activeObst[game.Workspace.Obstacles:GetChildren()[1]] -- get the active obstacle
		if obstacle then -- if it exists
			soundsv:PlayLocalSound(ReplicatedStorage.Sword) -- play a sword sound
			obstacle:Deflect() -- and deflect the obstacle
		end
	end
end)

local function onDeath() -- runs when the player dies
	if timerGui.Visible == true then -- if the timer is visible
		timerGui.Visible = false -- make it invisible
		tickSound.Volume = 0 -- turn off the ticking sound
	end
	stopLaunching() -- stop launching
	disappear() -- and make the tower disappear 
end

hum.Died:Connect(function() -- when the humanoid dies
	onDeath() -- run the function
end)

plr.CharacterAdded:Connect(function(newchar) -- when the player's character is added
	char = newchar -- set char to the character that was added
	hum = char:WaitForChild("Humanoid") -- set the the humanoid
	hum.Died:Connect(function() -- when the humanoid dies
		onDeath() -- run the function
	end)
end)

--done 😓
