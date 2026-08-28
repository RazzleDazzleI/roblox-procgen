--!strict
--[[
	Vertical profile — elevation along the alignment.

	Grade changes use symmetrical parabolic vertical curves, the same shape used
	in road design, because a linear grade break produces a visible crease the
	eye reads immediately as "generated".

	A VPI is a vertical point of intersection: station + elevation + curve length.
]]

local Profile = {}
Profile.__index = Profile

export type VPI = { station: number, elevation: number, curveLength: number? }

function Profile.new(vpis: { VPI })
	assert(#vpis >= 2, "a profile needs at least two VPIs")
	return setmetatable({ vpis = vpis }, Profile)
end

local function gradeBetween(a: VPI, b: VPI): number
	local run = b.station - a.station
	return run > 0 and (b.elevation - a.elevation) / run or 0
end

function Profile:elevationAt(station: number): number
	local vpis = self.vpis
	if station <= vpis[1].station then return vpis[1].elevation end
	if station >= vpis[#vpis].station then return vpis[#vpis].elevation end

	-- 1. Inside an interior VPI's vertical curve?
	--    The parabola spans HALF THE CURVE EITHER SIDE of the VPI. Handling only
	--    the approach half leaves a grade discontinuity at the crest — the exact
	--    crease this curve exists to remove.
	for i = 2, #vpis - 1 do
		local cur = vpis[i]
		local L = cur.curveLength or 0
		if L > 0 then
			local bvc, evc = cur.station - L / 2, cur.station + L / 2
			if station >= bvc and station <= evc then
				local gIn = gradeBetween(vpis[i - 1], cur)
				local gOut = gradeBetween(cur, vpis[i + 1])
				local x = station - bvc
				local yBVC = cur.elevation - gIn * (L / 2)
				-- y = y_bvc + g_in*x + (g_out - g_in)*x^2 / (2L)
				-- dy/dx is g_in at x=0 and g_out at x=L, so both tangents meet smoothly.
				return yBVC + gIn * x + (gOut - gIn) * x * x / (2 * L)
			end
		end
	end

	-- 2. Otherwise linear along the containing tangent.
	for i = 2, #vpis do
		if station <= vpis[i].station then
			local prev = vpis[i - 1]
			return prev.elevation + gradeBetween(prev, vpis[i]) * (station - prev.station)
		end
	end
	return vpis[#vpis].elevation
end

return Profile
