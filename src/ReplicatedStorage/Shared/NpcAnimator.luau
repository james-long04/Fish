--!strict
-- NpcAnimator (ModuleScript) — ReplicatedStorage/Shared/NpcAnimator
-- Plays Roblox's own default walk/idle animations on an NPC rig so villagers and pirates move naturally.

local NpcAnimator = {}

local IDS = {
	[Enum.HumanoidRigType.R15] = { idle = "rbxassetid://507766666", walk = "rbxassetid://507777826", run = "rbxassetid://507767714" },
	[Enum.HumanoidRigType.R6] = { idle = "rbxassetid://180435571", walk = "rbxassetid://180426354", run = "rbxassetid://180426354" },
}

function NpcAnimator.Attach(model: Model)
	local hum = model:FindFirstChildOfClass("Humanoid")
	if not hum then return end
	local animator = hum:FindFirstChildOfClass("Animator") or Instance.new("Animator", hum)
	local ids = IDS[hum.RigType] or IDS[Enum.HumanoidRigType.R15]
	local function load(id: string, looped: boolean, priority: Enum.AnimationPriority)
		local a = Instance.new("Animation")
		a.AnimationId = id
		local ok, track = pcall(animator.LoadAnimation, animator, a)
		if not ok then return nil end
		track.Looped = looped
		track.Priority = priority
		return track
	end
	local idle = load(ids.idle, true, Enum.AnimationPriority.Idle)
	local walk = load(ids.walk, true, Enum.AnimationPriority.Movement)
	if idle then idle:Play() end
	local moving = false
	hum.Running:Connect(function(speed)
		local now = speed > 0.5
		if now == moving then return end
		moving = now
		if moving then
			if walk then walk:Play(0.2) end
		else
			if walk then walk:Stop(0.2) end
		end
	end)
end

return NpcAnimator
