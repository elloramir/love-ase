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

-- sizes in bytes
local BYTE = 1
local WORD = 2
local SHORT = 2
local DWORD = 4
local LONG = 4
local FIXED = 4

-- parse data/text to number
local function read_num(data, size)
	local bytes = data:read(size)
	local hex = ""

	for i = size, 1, -1 do
		local char = string.sub(bytes, i, i)
		hex = hex .. string.format("%02X", string.byte(char))
	end

	return tonumber(hex, 16)
end

-- return a string by it size
local function read_string(data)
	local length = read_num(data, WORD)
	return data:read(length)
end

local function grab_header(data)
	local header = {}

	header.file_size = read_num(data, DWORD)
	header.magic_number = read_num(data, WORD)

	if header.magic_number ~= 0xA5E0 then
		error("Not a valid aseprite file")
	end

	header.frames_number = read_num(data, WORD)
	header.width = read_num(data, WORD)
	header.height = read_num(data, WORD)
	header.color_depth = read_num(data, WORD)
	header.opacity = read_num(data, DWORD)
	header.speed = read_num(data, WORD)

	-- skip
	read_num(data, DWORD * 2)

	header.palette_entry = read_num(data, BYTE)

	-- skip
	read_num(data, BYTE * 3)

	header.number_color = read_num(data, WORD)
	header.pixel_width = read_num(data, BYTE)
	header.pixel_height = read_num(data, BYTE)
	header.grid_x = read_num(data, SHORT)
	header.grid_y = read_num(data, SHORT)
	header.grid_width = read_num(data, WORD)
	header.grid_height = read_num(data, WORD)

	-- skip
	read_num(data, BYTE * 84)

	-- to the future
	header.frames = {}

	return header
end

local function grab_frame_header(data)
	local frame_header = {}

	frame_header.bytes_size = read_num(data, DWORD)
	frame_header.magic_number = read_num(data, WORD)

	if frame_header.magic_number ~= 0xF1FA then
		error("Corrupted file")
	end

	local old_chunks = read_num(data, WORD)

	frame_header.frame_duration = read_num(data, WORD)

	-- skip
	read_num(data, BYTE * 2)

	-- if 0, use old chunks as chunks
	local new_chunks = read_num(data, DWORD)

	if new_chunks == 0 then
		frame_header.chunks_number = old_chunks
	else
		frame_header.chunks_number = new_chunks
	end

	-- to the future
	frame_header.chunks = {}

	return frame_header
end

local function grab_color_profile(data)
	local color_profile = {}

	color_profile.type = read_num(data, WORD)
	color_profile.uses_fixed_gama = read_num(data, WORD)
	color_profile.fixed_game = read_num(data, FIXED)

	-- skip
	read_num(data, BYTE * 8)

	if color_profile.type ~= 1 then
		error("No suported color profile, use sRGB")
	end

	return color_profile
end

local function grab_palette(data)
	local palette = {}

	palette.entry_size = read_num(data, DWORD)
	palette.first_color = read_num(data, DWORD)
	palette.last_color = read_num(data, DWORD)
	palette.colors = {}

	-- skip
	read_num(data, BYTE * 8)

	for i = 1, palette.entry_size do
		local has_name = read_num(data, WORD)

		palette.colors[i] = {
			color = {
				read_num(data, BYTE),
				read_num(data, BYTE),
				read_num(data, BYTE),
				read_num(data, BYTE)}}

		if has_name == 1 then
			palette.colors[i].name = read_string(data)
		end
	end

	return palette
end

local function grab_old_palette(data)
	local palette = {}

	palette.packets = read_num(data, WORD)
	palette.colors_packet = {}

	for i = 1, palette.packets do
		palette.colors_packet[i] = {
			entries = read_num(data, BYTE),
			number = read_num(data, BYTE),
			colors = {}}

		for j = 1, palette.colors_packet[i].number do
			palette.colors_packet[i][j] = {
				read_num(data, BYTE),
				read_num(data, BYTE),
				read_num(data, BYTE)}
		end
	end

	return palette
end

local function grab_layer(data)
	local layer = {}

	layer.flags = read_num(data, WORD)
	layer.type = read_num(data, WORD)
	layer.child_level = read_num(data, WORD)
	layer.width = read_num(data, WORD)
	layer.height = read_num(data, WORD)
	layer.blend = read_num(data, WORD)
	layer.opacity = read_num(data, BYTE)

	-- skip
	read_num(data, BYTE * 3)

	layer.name = read_string(data)

	return layer
end

local function grab_cel(data, size)
	local cel = {}

	cel.layer_index = read_num(data, WORD)
	cel.x = read_num(data, WORD)
	cel.y = read_num(data, WORD)
	cel.opacity_level = read_num(data, BYTE)
	cel.type = read_num(data, WORD)

	read_num(data, BYTE * 7)

	if cel.type == 2 then
		cel.width = read_num(data, WORD)
		cel.height = read_num(data, WORD)
		cel.data = data:read(size - 26)
	end

	return cel
end

local function grab_tags(data)
	local tags = {}

	tags.number = read_num(data, WORD)
	tags.tags = {}

	-- skip
	read_num(data, BYTE * 8)

	for i = 1, tags.number do
		tags.tags[i] = {
			from = read_num(data, WORD),
			to = read_num(data, WORD),
			direction = read_num(data, BYTE),
			extra_byte = read_num(data, BYTE),
			color = read_num(data, BYTE * 3),
			skip_holder = read_num(data, BYTE * 8),
			name = read_string(data)}
	end

	return tags
end

local function grab_slice(data)
	local slice = {}

	slice.key_numbers = read_num(data, DWORD)
	slice.keys = {}
	slice.flags = read_num(data, DWORD)

	-- reserved?
	read_num(data, DWORD)

	slice.name = read_string(data)

	for i = 1, slice.key_numbers do
		slice.keys[i] = {
			frame = read_num(data, DWORD),
			x = read_num(data, DWORD),
			y = read_num(data, DWORD),
			width = read_num(data, DWORD),
			height = read_num(data, DWORD)}

		if slice.flags == 1 then
			slice.keys[i].center_x = read_num(data, DWORD)
			slice.keys[i].center_y = read_num(data, DWORD)
			slice.keys[i].center_width = read_num(data, DWORD)
			slice.keys[i].center_height = read_num(data, DWORD)
		elseif slice.flags == 2 then
			slice.keys[i].pivot_x = read_num(data, DWORD)
			slice.keys[i].pivot_y = read_num(data, DWORD)
		end
	end

	return slice
end

local function grab_user_data(data)
	local user_data = {}

	user_data.flags = read_num(data, DWORD)
	
	if user_data.flags == 1 then
		user_data.text = read_string(data)
	elseif user_data.flags == 2 then
		user_data.colors = read_num(data, BYTE * 4)
	end

	return user_data
end

local function grab_chunk(data)
	local chunk = {}
	chunk.size = read_num(data, DWORD)
	chunk.type = read_num(data, WORD)

	if chunk.type == 0x2007 then
		chunk.data = grab_color_profile(data)
	elseif chunk.type == 0x2019 then
		chunk.data = grab_palette(data)
	elseif chunk.type == 0x0004 then
		chunk.data = grab_old_palette(data)
	elseif chunk.type == 0x2004 then
		chunk.data = grab_layer(data)
	elseif chunk.type == 0x2005 then
		chunk.data = grab_cel(data, chunk.size)
	elseif chunk.type == 0x2018 then
		chunk.data = grab_tags(data)
	elseif chunk.type == 0x2022 then
		chunk.data = grab_slice(data)
	elseif chunk.type == 0x2020 then
		chunk.data = grab_user_data(data)
	end

	return chunk
end

local function ase_loader(src)
	local data = io.open(src, "rb")
	assert(data, "can't open " .. src)
	local ase = {}

	-- parse header
	ase.header = grab_header(data)

	-- parse frames
	for i = 1, ase.header.frames_number do
		ase.header.frames[i] = grab_frame_header(data)

		-- parse frames chunks
		for j = 1, ase.header.frames[i].chunks_number do
			ase.header.frames[i].chunks[j] = grab_chunk(data)
		end
	end

	data.close()
	return ase
end

return ase_loader