local loader = require "loader"

love.graphics.setDefaultFilter("nearest", "nearest")

local player_ase = loader("player.ase")
local chunk = player_ase.header.frames[2].chunks[1].data
local buffer = love.data.decompress("data", "zlib", chunk.data)
local img_data = love.image.newImageData(chunk.width, chunk.height, "rgba8", buffer)
local image = love.graphics.newImage(img_data)

function love.draw()
	love.graphics.draw(image, 0, 0, 0, 10, 10)
end