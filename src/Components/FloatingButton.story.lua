local Hoarcekat = script:FindFirstAncestor("Hoarcekat")

local Assets = require(Hoarcekat.Plugin.Assets)
local FloatingButton = require(script.Parent.FloatingButton)
local Roact = require(Hoarcekat.Vendor.Roact)

local e = Roact.createElement

local function TestFloatingButton()return function()return function()
	local t = {}
	error('failed to be cool')

	return e(FloatingButton, {
		Activated = function()
			print("activated!")
		end,
		Image = Assets.preview,
		ImageSize = UDim.new(0, 24),
		Size = UDim.new(0, 40),
	})
end
end
end

return function(target)
	local d = TestFloatingButton()()
	local handle = Roact.mount(e(d), target, "FloatingButton")

	return function()
		Roact.unmount(handle)
	end
end
