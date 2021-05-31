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

### ouput structure:

```lua
local ase = {
  header = {
    file_size = int,
    magic_number = int, -- (need to be 0xA5E0)
    frames_number = int,
    width = int,
    height = int,
    color_depth = int,
    opacity = int,
    speed = int,
    palette_entry = int,
    number_color = int,
    pixel_width = int,
    pixel_height = int,
    grid_x = int,
    grid_y = int,
    grid_width = int,
    grid_height = int,
    frames = {} -- (array of frame)
  }
}

local frame = {
  bytes_size = int,
  magic_number = int, -- (need to be 0xF1FA)
  frame_duration = int,
  chunks_number = int,
  
   -- (array of chunk)
  chunks = {
    type = int,
    
    -- the data will be defined by the chunk type
    data = {}
  }
}

-- chunk can have multiple types you can see it on code 😜, but i'll show the most essentials

-- type: 0x2005
local chunk_cel_data = {
  layer_index = int,
  x = int,
  y = int,
  opacity_level = int,
  type = int, -- (only type 2 are acepted)
  width = int,
  height = int,
  data = string -- (Base64 string, this is the frame image compressed)
}

-- type: 0x2018
local chunk_tags_data = {
  number = int,
  
  -- array of tag (this inside is just anexample)
  tags = {
    {
      from = int,
      to = int,
      direction = int,
      name = string
    }
  }
}
```
