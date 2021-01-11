local CoreGui = game:GetService("CoreGui")
local Selection = game:GetService("Selection")

local Hoarcekat = script:FindFirstAncestor("Hoarcekat")

local Assets = require(Hoarcekat.Plugin.Assets)
local EventConnection = require(script.Parent.EventConnection)
local FloatingButton = require(script.Parent.FloatingButton)
local Maid = require(Hoarcekat.Plugin.Maid)
local Roact = require(Hoarcekat.Vendor.Roact)
local RoactRodux = require(Hoarcekat.Vendor.RoactRodux)

local e = Roact.createElement

local gui = Instance.new('ScreenGui')

local Preview = Roact.PureComponent:extend("Preview")
local sources = {}
local addTos = {}
local addTo, lineNum, restMsg
function Preview:init()
	self.previewRef = Roact.createRef()

	self.monkeyRequireCache = {}
	self.monkeyRequireMaid = Maid.new()

	self.monkeyGlobalTable = {}

	local display = Instance.new("ScreenGui")
	display.Name = "HoarcekatDisplay"
	self.display = display

	self.expand = false

	self.monkeyRequire = function(otherScript)
		if self.monkeyRequireCache[otherScript] then
			return self.monkeyRequireCache[otherScript]
		end

		local src = otherScript.Source
		if otherScript == addTo then
			local lines = src:split('\n')
			lines[lineNum] = 'warn"[HoarceKat] Failed displaying story due to error" warn"'..otherScript:GetFullName()..restMsg..'" '..lines[lineNum]
			src = table.concat(lines, '\n')
		end

		-- loadstring is used to avoid cache while preserving `script` (which requiring a clone wouldn't do)
		local result, parseError = loadstring(src)
		if result == nil then
			error(("Could not parse %s: %s"):format(otherScript:GetFullName(), parseError))
			return
		end

		local fenv = setmetatable({
			require = self.monkeyRequire,
			script = otherScript,
			_G = self.monkeyGlobalTable,
		}, {
			__index = getfenv(),
		})

		setfenv(result, fenv)

		local output = result()
		self.monkeyRequireCache[otherScript] = output

		self.monkeyRequireMaid:GiveTask(otherScript.Changed:connect(function()
			self:refreshPreview()
		end))

		sources[otherScript] = otherScript.Source

		return output
	end

	self.openSelection = function()
		local preview = self.previewRef:getValue()
		if preview then
			Selection:Set({ preview })
		end
	end

	self.expandSelection = function()
		self.expand = not self.expand
		self.display.Parent = self.expand and CoreGui or nil

		self:refreshPreview()
	end
end

function Preview:didMount()
	self:refreshPreview()
end

function Preview:didUpdate()
	self:refreshPreview()
end

function Preview:willUnmount()
	self.monkeyRequireMaid:DoCleaning()
end

function Preview:refreshPreview()
	if self.cleanup then
		local ok, result = pcall(self.cleanup)
		if not ok then
			warn("Error cleaning up story: " .. result)
		end

		self.cleanup = nil
	end

	local preview = self.previewRef:getValue()
	if preview ~= nil then
		preview:ClearAllChildren()
	end

	local selectedStory = self.props.selectedStory
	if selectedStory then
		self.monkeyRequireCache = {}
		self.monkeyGlobalTable = {}
		self.monkeyRequireMaid:DoCleaning()

		local requireOk, result = xpcall(self.monkeyRequire, debug.traceback, selectedStory)
		if not requireOk then
			warn("Error requiring story: " .. result)
			return
		end

		local execOk, cleanup = xpcall(function()
			return result(self.expand and self.display or self.previewRef:getValue())
		end, function(msg)
			local line = tonumber(msg:match('%b[]:(%d+)'))

			-- local lines = selectedStory.Source:split('\n')
			-- warn(msg)
			local TestService = game:GetService('TestService')

			local trace = debug.traceback()
			local split = trace:split('\n')

			local stack = {}
			local stacks = {}

			local merged = {}
			local first = false
			for i, l in ipairs(split) do
				if i ~= 1 then
					table.insert(merged, l)
				end

				local extra, num, func
				if not first then
					extra, num, func = l:match('(.+):('..line..')')

					if num then
						func = ''
						first = true
					end
				else
					extra, num, func = l:match('(.+):(%d+) (.+)')
				end


				if not num or not func then continue end
				if l:find('Hoarcekat.Plugin.', nil, false) then
					break
				end

				merged[#merged] = extra

				table.insert(stacks, {line = num, func = func, data = table.concat(merged, '\n')})

				merged = {}
			end

			table.remove(split, 1)
			trace = table.concat(split, '\n')

			local first = trace:find(':'..line)

			local foundFile
			for file, source in pairs(sources) do
				if not foundFile and source:sub(1, first - 1) == trace:sub(1, first - 1) then
					foundFile = file
				end

				for _, info in ipairs(stacks) do
					-- print('MY DATA IS ', info.data, '\n\n')
					-- print('THEIR DATA IS ', source:sub(1, #info.data), '\n\n\n\n\n\n')
					if source:sub(1, #info.data) == info.data then
						info.file = file
						-- break
					end
				end
			end

			for _, info in ipairs(stacks) do
				local file = info.file and info.file:GetFullName() or 'PATH'
				table.insert(stack, '\t\tScript '..'\''..file..'\', Line '..info.line..(info.func ~= '' and ' - '..info.func or ''))
			end

			-- print(stacks)

			addTo = foundFile
			restMsg = msg:match('%b[](.+)')
			lineNum = line

			sources = {}

			self.monkeyRequireCache = {}
			self.monkeyGlobalTable = {}
			self.monkeyRequireMaid:DoCleaning()

			local go = loadstring(selectedStory.Source)

			local fenv = setmetatable({
				require = self.monkeyRequire,
				script = selectedStory,
				_G = self.monkeyGlobalTable,
			}, {
				__index = getfenv(),
			})

			setfenv(go, fenv)
			pcall(function()
				return go()(gui)
			end)


			TestService:Message('\n\tStack Begin\n'..table.concat(stack, '\n')..'\n\tStack End')

			gui:ClearAllChildren()

			sources = {}
			addTos = {}
			addTo, lineNum, restMsg = nil, nil, nil


			-- local path = selectedStory:GetFullName()

			-- -- TestService:Error(path..a:match('%b[](.+)'))
			-- -- warn('- '..selectedStory.Name..':11')
			-- TestService:Message('\nStack Begin\n'..debug.traceback(nil, 10)..'Stack End')

			return ''
		end)

		if not execOk then
			-- warn("Error executing story: " .. cleanup)
			return
		end

		self.cleanup = cleanup
	end
end

function Preview:render()
	local selectedStory = self.props.selectedStory

	return e("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
	}, {
		UIPadding = e("UIPadding", {
			PaddingLeft = UDim.new(0, 5),
			PaddingTop = UDim.new(0, 5),
		}),

		Preview = e("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			[Roact.Ref] = self.previewRef,
		}),

		SelectButton = e("Frame", {
			AnchorPoint = Vector2.new(1, 1),
			BackgroundTransparency = 1,
			Position = UDim2.fromScale(0.99, 0.99),
			Size = UDim2.fromOffset(40, 40),
		}, {
			Button = e(FloatingButton, {
				Activated = self.openSelection,
				Image = "rbxasset://textures/ui/InspectMenu/ico_inspect@2x.png",
				ImageSize = UDim.new(0, 24),
				Size = UDim.new(0, 40),
			}),
		}),

		ExpandButton = e("Frame", {
			AnchorPoint = Vector2.new(1, 1),
			BackgroundTransparency = 1,
			Position = UDim2.new(0.99, -45, 0.99),
			Size = UDim2.fromOffset(40, 40),
		}, {
			Button = e(FloatingButton, {
				Activated = self.expandSelection,
				Image = "rbxasset://textures/ui/VR/toggle2D.png",
				ImageSize = UDim.new(0, 24),
				Size = UDim.new(0, 40),
			}),
		}),

		TrackRemoved = selectedStory and e(EventConnection, {
			callback = function()
				if not selectedStory:IsDescendantOf(game) then
					self.props.endPreview()
				end
			end,
			event = selectedStory.AncestryChanged,
		}),
	})
end

return RoactRodux.connect(function(state)
	return {
		selectedStory = state.StoryPicker,
	}
end, function(dispatch)
	return {
		endPreview = function()
			dispatch({
				type = "SetSelectedStory",
			})
		end,
	}
end)(Preview)
