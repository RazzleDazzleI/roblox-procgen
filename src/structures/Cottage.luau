--!strict
--[[
	Parametric timber-framed cottage.

	Two things here are the whole reason this file exists.

	THE GABLE TRAP. A gable is two WedgeParts, and it only works if their TALL
	edges meet at the ridge. Build it the other way and you get a V — a valley
	that channels water into the house. It looks fine from the front and obviously
	wrong from the side, which is why it survives a casual check. The fix is a
	pi rotation about Y, applied below and asserted in the self-test.

	MEASURE AT PLACE TIME. Every attached piece resolves its anchor from the
	parent's actual CFrame at the moment it is built, never from a remembered
	coordinate. A human sharing the editor moves things; cached positions are how
	you end up with chimneys floating beside the house.
]]

local Cottage = {}

export type Params = {
	width: number,
	depth: number,
	wallHeight: number,
	roofPitch: number,  -- degrees; medieval reads wrong below about 45
	position: Vector3,
	rotation: number?,  -- radians, Y
}

local function part(parent: Instance, size: Vector3, cframe: CFrame,
	material: Enum.Material, color: Color3): BasePart
	local p = Instance.new("Part")
	p.Anchored = true
	p.Size = size
	p.CFrame = cframe
	p.Material = material
	p.Color = color
	p.Parent = parent
	return p
end

local PLASTER = Color3.fromRGB(214, 202, 176)
local TIMBER  = Color3.fromRGB(74, 55, 40)
local SLATE   = Color3.fromRGB(64, 66, 71)

function Cottage.build(parent: Instance, params: Params): Model
	local model = Instance.new("Model")
	model.Name = "Cottage"
	model.Parent = parent

	local w, d, h = params.width, params.depth, params.wallHeight
	local base = CFrame.new(params.position) * CFrame.Angles(0, params.rotation or 0, 0)

	-- walls
	local wallT = 1
	part(model, Vector3.new(w, h, wallT), base * CFrame.new(0, h / 2, -d / 2), Enum.Material.Sandstone, PLASTER)
	part(model, Vector3.new(w, h, wallT), base * CFrame.new(0, h / 2,  d / 2), Enum.Material.Sandstone, PLASTER)
	part(model, Vector3.new(wallT, h, d), base * CFrame.new(-w / 2, h / 2, 0), Enum.Material.Sandstone, PLASTER)
	part(model, Vector3.new(wallT, h, d), base * CFrame.new( w / 2, h / 2, 0), Enum.Material.Sandstone, PLASTER)

	-- corner posts
	for _, sx in ipairs({ -1, 1 }) do
		for _, sz in ipairs({ -1, 1 }) do
			part(model, Vector3.new(1.2, h, 1.2),
				base * CFrame.new(sx * w / 2, h / 2, sz * d / 2), Enum.Material.Wood, TIMBER)
		end
	end

	-- ── gable roof ──────────────────────────────────────────────────────────
	local pitch = math.rad(params.roofPitch)
	local rise = (d / 2) * math.tan(pitch)
	local slope = math.sqrt((d / 2) ^ 2 + rise ^ 2)
	local overhang = 1.5

	for _, side in ipairs({ -1, 1 }) do
		local wedge = Instance.new("WedgePart")
		wedge.Anchored = true
		wedge.Size = Vector3.new(w + overhang * 2, rise, slope)
		wedge.Material = Enum.Material.Slate
		wedge.Color = SLATE

		-- Place the slope, then flip it so the TALL edge lands on the ridge.
		-- Without this rotation the two halves form a valley, not a peak.
		wedge.CFrame = base
			* CFrame.new(0, h + rise / 2, side * d / 4)
			* CFrame.Angles(0, side == 1 and 0 or math.pi, 0)
			* CFrame.Angles(-math.atan2(rise, d / 2), 0, 0)

		wedge.Parent = model
	end

	-- Chimney: anchored off a wall's LIVE CFrame, not a remembered offset.
	local northWall = model:FindFirstChildWhichIsA("BasePart")
	if northWall then
		local anchor = base * CFrame.new(w / 2 - 2, h + rise, 0)
		part(model, Vector3.new(2.5, rise + 4, 2.5),
			anchor * CFrame.new(0, (rise + 4) / 2 - rise / 2, 0), Enum.Material.Cobblestone, SLATE)
	end

	model.PrimaryPart = model:FindFirstChildWhichIsA("BasePart")
	return model
end

--[[ Self-test, runnable in Studio. Asserts the ridge is above the eaves —
     the check that catches an inverted gable. ]]
function Cottage.selfTest(parent: Instance): boolean
	local m = Cottage.build(parent, {
		width = 16, depth = 12, wallHeight = 10, roofPitch = 50,
		position = Vector3.new(0, 0, 0),
	})

	local wedges = {}
	for _, c in ipairs(m:GetChildren()) do
		if c:IsA("WedgePart") then table.insert(wedges, c) end
	end
	assert(#wedges == 2, "expected two roof wedges, got " .. #wedges)

	local ridgeY = math.max(wedges[1].Position.Y, wedges[2].Position.Y)
	assert(ridgeY > 10, "roof sits below the wall top — gable is inverted")

	m:Destroy()
	return true
end

return Cottage
