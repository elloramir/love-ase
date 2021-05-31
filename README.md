# love2d ASE loader

Helps you to read ASE files without parsing them in a json or something. So useful for development, but I recommend not using it in production, loading files this way is slower than just passing src data and this loader doesn't use third-party libs, everything here is written in pure LUA, so no use it in production :smile:. You can find more details [here](https://github.com/aseprite/aseprite/blob/master/docs/ase-file-specs.md).

### example:

```lua
local loader = require "loader"

-- pixelart preset
love.graphics.setDefaultFilter("nearest", "nearest")

-- load file
local player_ase = loader("player.ase")

-- get random chunk from a random frame
local chunk = player_ase.header.frames[5].chunks[1].data

-- decompress image bytes
local buffer = love.data.decompress("data", "zlib", chunk.data)

-- parse it into a love2d image
local img_data = love.image.newImageData(chunk.width, chunk.height, "rgba8", buffer)
local image = love.graphics.newImage(img_data)

function love.draw()
	love.graphics.draw(image, 0, 0, 0, 10, 10)
end 
```
