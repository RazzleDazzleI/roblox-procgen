--!strict
--[[
	Horizontal alignment — a road centerline as stations and offsets.

	A road is not a list of points you drop on terrain. It is a centerline with
	stations (distance along it) and offsets (distance perpendicular to it).
	Every downstream decision — where the corridor cuts, where pads sit, where
	the bridge lands — is expressed in that coordinate system, which is why the
	geometry stays coherent when you change one PI instead of falling apart.

	PI = point of intersection: the corner where two tangents meet.
]]

local Alignment = {}
Alignment.__index = Alignment

export type Vec2 = { x: number, z: number }

-- Build from PIs. Curve fitting is deliberately omitted: at village scale the
-- tangent run is short enough that a chamfer reads as a curve once the corridor
-- is swept and the terrain is smoothed.
function Alignment.new(pis: { Vec2 })
	assert(#pis >= 2, "an alignment needs at least two PIs")

	local self = setmetatable({}, Alignment)
	self.pis = pis
	self.stations = { 0 }

	local total = 0
	for i = 2, #pis do
		local dx, dz = pis[i].x - pis[i - 1].x, pis[i].z - pis[i - 1].z
		total += math.sqrt(dx * dx + dz * dz)
		self.stations[i] = total
	end
	self.length = total
	return self
end

--[[ World position at a station, offset metres to the right of travel. ]]
function Alignment:pointAt(station: number, offset: number?): Vec2
	local off = offset or 0
	local s = math.clamp(station, 0, self.length)

	for i = 2, #self.pis do
		if s <= self.stations[i] or i == #self.pis then
			local a, b = self.pis[i - 1], self.pis[i]
			local segLen = self.stations[i] - self.stations[i - 1]
			local t = segLen > 0 and (s - self.stations[i - 1]) / segLen or 0

			local dx, dz = (b.x - a.x) / math.max(segLen, 1e-6), (b.z - a.z) / math.max(segLen, 1e-6)
			-- right-hand normal of the direction of travel
			local nx, nz = dz, -dx

			return {
				x = a.x + (b.x - a.x) * t + nx * off,
				z = a.z + (b.z - a.z) * t + nz * off,
			}
		end
	end
	error("unreachable")
end

--[[ Nearest station/offset for a world point. Used to ask "is this inside the
     corridor?" without hit-testing geometry. ]]
function Alignment:project(x: number, z: number): (number, number)
	local bestS, bestOff, bestDist = 0, math.huge, math.huge

	for i = 2, #self.pis do
		local a, b = self.pis[i - 1], self.pis[i]
		local vx, vz = b.x - a.x, b.z - a.z
		local len2 = vx * vx + vz * vz
		if len2 > 0 then
			local t = math.clamp(((x - a.x) * vx + (z - a.z) * vz) / len2, 0, 1)
			local px, pz = a.x + vx * t, a.z + vz * t
			local dx, dz = x - px, z - pz
			local dist = math.sqrt(dx * dx + dz * dz)

			if dist < bestDist then
				bestDist = dist
				bestS = self.stations[i - 1] + t * (self.stations[i] - self.stations[i - 1])
				-- sign the offset so left/right is meaningful
				local sign = (dx * vz - dz * vx) >= 0 and 1 or -1
				bestOff = dist * sign
			end
		end
	end
	return bestS, bestOff
end

return Alignment
