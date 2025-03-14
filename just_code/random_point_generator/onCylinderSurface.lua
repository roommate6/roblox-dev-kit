local function getRandomPointOnCylinderSurface(cylinder: Part, yOffset: number?, padding: number?): Vector3?
	yOffset = tonumber(yOffset) or 0
	assert(yOffset)
	padding = tonumber(padding) or 0
	assert(padding)

	local diameter = math.min(cylinder.Size.Y, cylinder.Size.Z)
	diameter = math.max(0, diameter - padding)

	if diameter == 0 then
		warn("Diameter can't be 0.")
		return nil
	end

	local radius = diameter / 2

	local x = cylinder.Size.X / 2 + yOffset
	local y
	local z

	local generator = Random.new()
	while true do
		y = generator:NextNumber() * diameter - radius
		z = generator:NextNumber() * diameter - radius

		if y * y + z * z < radius * radius then
			break
		end
	end

	local localPoint = Vector3.new(x, y, z)
	local worldPoint = cylinder.CFrame:PointToWorldSpace(localPoint)
	return worldPoint
end
