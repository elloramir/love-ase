--[[
MIT License

Copyright (c) 2021 Pedro Lucas (github.com/elloramir)

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
]]--

-- https://www.lua.org/manual/5.3/manual.html#6.4.2
local BYTE  = { "B",  1 }
local WORD  = { "H",  2 }
local SHORT = { "h",  2 }
local DWORD = { "I4", 4 }
local LONG  = { "i4", 4 }
local FIXED = { "i4", 4 }

-- unpack file data into a number
local function read_num(file, fmt, amount)
	amount = amount or 1
	return love.data.unpack(fmt[1], file:read(fmt[2] * amount), 1)
end	

local function read_string(file)
	return file:read(read_num(file, WORD))
end

local function grab_header(file)
	local header = {}

	header.file_size = read_num(file, DWORD)
	header.magic_number = read_num(file, WORD)
	
	if header.magic_number ~= 0xA5E0 then
		error("Not a valid aseprite file")
	end

	header.frames_number = read_num(file, WORD)
	header.width = read_num(file, WORD)
	header.height = read_num(file, WORD)
	header.color_depth = read_num(file, WORD)
	header.opacity = read_num(file, DWORD)
	header.speed = read_num(file, WORD)

	-- skip
	read_num(file, DWORD, 2)

	header.palette_entry = read_num(file, BYTE)

	-- skip
	read_num(file, BYTE, 3)

	header.number_color = read_num(file, WORD)
	header.pixel_width = read_num(file, BYTE)
	header.pixel_height = read_num(file, BYTE)
	header.grid_x = read_num(file, SHORT)
	header.grid_y = read_num(file, SHORT)
	header.grid_width = read_num(file, WORD)
	header.grid_height = read_num(file, WORD)

	-- skip
	read_num(file, BYTE, 84)

	-- to the future
	header.frames = {}

	return header
end

local function grab_frame_header(file)
	local frame_header = {}

	frame_header.bytes_size = read_num(file, DWORD)
	frame_header.magic_number = read_num(file, WORD)

	if frame_header.magic_number ~= 0xF1FA then
		error("Corrupted file")
	end

	local old_chunks = read_num(file, WORD)

	frame_header.frame_duration = read_num(file, WORD)

	-- skip
	read_num(file, BYTE, 2)

	-- if 0, use old chunks as chunks
	local new_chunks = read_num(file, DWORD)

	if new_chunks == 0 then
		frame_header.chunks_number = old_chunks
	else
		frame_header.chunks_number = new_chunks
	end

	-- to the future
	frame_header.chunks = {}

	return frame_header
end

local function grab_color_profile(file)
	local color_profile = {}

	color_profile.type = read_num(file, WORD)
	color_profile.uses_fixed_gama = read_num(file, WORD)
	color_profile.fixed_game = read_num(file, FIXED)

	-- skip
	read_num(file, BYTE, 8)

	if color_profile.type ~= 1 then
		error("No suported color profile, use sRGB")
	end

	return color_profile
end

local function grab_palette(file)
	local palette = {}

	palette.entry_size = read_num(file, DWORD)
	palette.first_color = read_num(file, DWORD)
	palette.last_color = read_num(file, DWORD)
	palette.colors = {}

	-- skip
	read_num(file, BYTE, 8)

	for i = 1, palette.entry_size do
		local has_name = read_num(file, WORD)

		palette.colors[i] = {
			color = {
				read_num(file, BYTE),
				read_num(file, BYTE),
				read_num(file, BYTE),
				read_num(file, BYTE)}}

		if has_name == 1 then
			palette.colors[i].name = read_string(file)
		end
	end

	return palette
end

local function grab_old_palette(file)
	local palette = {}

	palette.packets = read_num(file, WORD)
	palette.colors_packet = {}

	for i = 1, palette.packets do
		palette.colors_packet[i] = {
			entries = read_num(file, BYTE),
			number = read_num(file, BYTE),
			colors = {}}
		
		-- (0 means 256)
		if palette.colors_packet[i].number == 0 then
			palette.colors_packet[i].number = 256
		end

		for j = 1, palette.colors_packet[i].number do
			palette.colors_packet[i][j] = {
				read_num(file, BYTE),
				read_num(file, BYTE),
				read_num(file, BYTE)}
		end
	end

	return palette
end

local function grab_layer(file)
	local layer = {}

	layer.flags = read_num(file, WORD)
	layer.type = read_num(file, WORD)
	layer.child_level = read_num(file, WORD)
	layer.width = read_num(file, WORD)
	layer.height = read_num(file, WORD)
	layer.blend = read_num(file, WORD)
	layer.opacity = read_num(file, BYTE)

	-- skip
	read_num(file, BYTE, 3)

	layer.name = read_string(file)

	return layer
end

local function grab_cel(file, size)
	local cel = {}

	cel.layer_index = read_num(file, WORD)
	cel.x = read_num(file, WORD)
	cel.y = read_num(file, WORD)
	cel.opacity_level = read_num(file, BYTE)
	cel.type = read_num(file, WORD)

	read_num(file, BYTE, 7) -- skip

	-- raw image data
	if cel.type == 0 then
		cel.width = read_num(file, WORD)
		cel.height = read_num(file, WORD)
		cel.data = {}

		for i = 1, cel.width * cel.height do
			cel.data[i] = {
				read_num(file, BYTE),
				read_num(file, BYTE),
				read_num(file, BYTE),
				read_num(file, BYTE)
			}
		end
	
	-- linked cel
	elseif cel.type == 1 then
		cel.frame_pos_link = read_num(file, WORD)

	-- compressed image
	elseif cel.type == 2 then
		cel.width = read_num(file, WORD)
		cel.height = read_num(file, WORD)
		cel.data = file:read(size - 26)
	
	-- compressed tilemap
	elseif cel.type == 3 then
		cel.width = read_num(file, WORD)
		cel.height = read_num(file, WORD)
		cel.bits_per_tile = read_num(file, WORD)
		cel.bitmask_tile_id = read_num(file, DWORD) -- allways 32 bits
		cel.bitmask_x_flip = read_num(file, DWORD)
		cel.bitmask_y_flip = read_num(file, DWORD)
		cel.bitmask_rotation = read_num(file, DWORD)

	    read_num(file, BYTE, 10) -- skip

		cel.data = {}
		for i = 1, cel.width * cel.height do
			cel.data[i] = { read_num(file, DWORD)}
		end
	end

	return cel
end

local function grab_tags(file)
	local tags = {}

	tags.number = read_num(file, WORD)
	tags.tags = {}

	-- skip
	read_num(file, BYTE, 8)

	for i = 1, tags.number do
		tags.tags[i] = {
			from = read_num(file, WORD),
			to = read_num(file, WORD),
			direction = read_num(file, BYTE),
			extra_byte = read_num(file, BYTE),
			color = read_num(file, BYTE, 3),
			skip_holder = read_num(file, BYTE, 8),
			name = read_string(file)}
	end

	return tags
end

local function grab_slice(file)
	local slice = {}

	slice.key_numbers = read_num(file, DWORD)
	slice.keys = {}
	slice.flags = read_num(file, DWORD)

	-- reserved?
	read_num(file, DWORD)

	slice.name = read_string(file)

	for i = 1, slice.key_numbers do
		slice.keys[i] = {
			frame = read_num(file, DWORD),
			x = read_num(file, DWORD),
			y = read_num(file, DWORD),
			width = read_num(file, DWORD),
			height = read_num(file, DWORD)}

		if slice.flags == 1 then
			slice.keys[i].center_x = read_num(file, DWORD)
			slice.keys[i].center_y = read_num(file, DWORD)
			slice.keys[i].center_width = read_num(file, DWORD)
			slice.keys[i].center_height = read_num(file, DWORD)
		elseif slice.flags == 2 then
			slice.keys[i].pivot_x = read_num(file, DWORD)
			slice.keys[i].pivot_y = read_num(file, DWORD)
		end
	end

	return slice
end

local function grab_user_data(file)
	local user_data = {}

	user_data.flags = read_num(file, DWORD)
	
	if user_data.flags == 1 then
		user_data.text = read_string(file)
	elseif user_data.flags == 2 then
		user_data.colors = read_num(file, BYTE, 4)
	end

	return user_data
end

local function grab_tileset(file)
	local tileset = {}

	tileset.id = read_num(file, DWORD)
	tileset.flags = read_num(file, DWORD)
	tileset.num_tiles = read_num(file, DWORD)
	tileset.tile_width = read_num(file, WORD)
	tileset.tile_height = read_num(file, WORD)
	tileset.base_index = read_num(file, SHORT)

	-- skip
	read_num(file, BYTE, 14)

	tileset.name = read_string(file)

	if tileset.flags == 1 then
		tileset.external_id = read_num(file, DWORD)
		tileset.tileset_id_in_external_file = read_num(file, DWORD)
	elseif tileset.flags == 2 then
		error("Compressed tileset not supported yet")
	end

	return tileset
end

local function grab_chunk(file)
	local chunk = {}
	chunk.size = read_num(file, DWORD)
	chunk.type = read_num(file, WORD)

	if chunk.type == 0x2007 then
		chunk.data = grab_color_profile(file)
	elseif chunk.type == 0x2019 then
		chunk.data = grab_palette(file)
	elseif chunk.type == 0x0004 then
		chunk.data = grab_old_palette(file)
	elseif chunk.type == 0x2004 then
		chunk.data = grab_layer(file)
	elseif chunk.type == 0x2005 then
		chunk.data = grab_cel(file, chunk.size)
	elseif chunk.type == 0x2018 then
		chunk.data = grab_tags(file)
	elseif chunk.type == 0x2022 then
		chunk.data = grab_slice(file)
	elseif chunk.type == 0x2020 then
		chunk.data = grab_user_data(file)
	elseif chunk.type == 0x2023 then
		chunk.data = grab_tileset(file)
	end

	return chunk
end

local function ase_loader(src)
    local file = love.filesystem.newFile(src)
    -- error if file is not found
    if not file:open("r") then
        error("File not found: " .. src)
    end
    file:open("r")

	local ase = {}

	-- parse header
	ase.header = grab_header(file)

	-- parse frames
	for i = 1, ase.header.frames_number do
		ase.header.frames[i] = grab_frame_header(file)

		-- parse frames chunks
		for j = 1, ase.header.frames[i].chunks_number do
			ase.header.frames[i].chunks[j] = grab_chunk(file)
		end
	end
    
    file:close()
	return ase
end

return ase_loader