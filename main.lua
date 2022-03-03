-- example
local loader = require "ase-loader"
local sprite = {}

function sprite:load(dir)
	local file = loader(dir)

	-- size
	self.width = file.header.width
	self.height = file.header.height
	self.frames = {}
	self.tags = {}
	self.active = "" -- active tag
	self.index = 1 -- actual frame
	self.time = 0 -- current time elapsed

	for _, frame in ipairs(file.header.frames) do
		for _, chunk in ipairs(frame.chunks) do
			-- frame image data
			if chunk.type == 0x2005 then
				local cel = chunk.data
				local buffer = love.data.decompress("data", "zlib", cel.data)
				local data = love.image.newImageData(cel.width, cel.height, "rgba8", buffer)
				local image = love.graphics.newImage(data)
				local canvas = love.graphics.newCanvas(self.width, self.height)

				-- you need to draw in a canvas before.
				-- frame images can be of different sizes
				-- but never bigger than the header width and height
				love.graphics.setCanvas(canvas)
				love.graphics.draw(image, cel.x, cel.y)
				love.graphics.setCanvas()

				table.insert(self.frames, {
					image = canvas,
					duration = frame.frame_duration / 1000})

			-- tag
			elseif chunk.type == 0x2018 then
				for i, tag in ipairs(chunk.data.tags) do
					-- first tag as default
					if i == 1 then
						self.active = tag.name
					end

					-- aseprite use 0 notation to begin
					-- but in lua, everthing starts in 1
					tag.to = tag.to + 1
					tag.from = tag.from + 1
					tag.frames = tag.to - tag.from
					self.tags[tag.name] = tag
				end
			end
		end
	end
end

function sprite:play(name)
	assert(self.tags[name], "invalid tag: " .. name)

	-- if arent playing...
	-- prevent indexes bigger than tag to
	if self.active ~= name then
		self.index = self.tags[name].from
	end

	self.active = name
end

function sprite:update(delta)
	assert(self.active, "no tag playing, sure you set this in aseprite?")
	local tag = self.tags[self.active]

	-- time tracker are useless on single frames...
	if (tag.to - tag.from) ~= 0 then
		self.time = self.time + delta

		-- next frame
		if self.time >= self.frames[self.index].duration then
			self.index = self.index + 1
			self.time = 0 -- you can change to "self.time - frame.duration" as well

			-- reach the end, return to begin
			if self.index > tag.to then
				self.index = tag.from
			end
		end
	end
end

function sprite:draw(x, y, angle, sx, sy)
	love.graphics.draw(self.frames[self.index].image, x, y, angle, sx, sy)
end

function love.load()
	love.graphics.setDefaultFilter("nearest", "nearest")
	sprite:load("player.ase")
	sprite:play("run")
end

function love.update(delta)
	sprite:update(delta)
end

function love.draw()
	sprite:draw(0, 0, 0, 10, 10)
end