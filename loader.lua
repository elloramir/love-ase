local data = nil

-- size
local BYTE = 1
local WORD = 2
local SHORT = 2
local DWORD = 4
local LONG = 4
local FIXED = 4

local function read_byte(size)
	local bytes = data:read(size)
	local hex = ""

	for i = size, 1, -1 do
		local char = string.sub(bytes, i, i)

		hex = hex .. string.format("%02X", string.byte(char))
	end

	return tonumber(hex, 16)
end

local function read_string()
	local length = read_byte(WORD)
	local str = ""

	for i = 1, length do
		str = str .. tostring(read_byte(BYTE))
	end

	return str
end

local function grab_header()
	local header = {}

	header.file_size = read_byte(DWORD)
	header.magic_number = read_byte(WORD)

	if header.magic_number ~= 0xA5E0 then
		print("Not a valid aseprite file")
		return
	end

	header.frames_number = read_byte(WORD)
	header.width = read_byte(WORD)
	header.height = read_byte(WORD)
	header.color_depth = read_byte(WORD)
	header.opacity = read_byte(DWORD)
	header.speed = read_byte(WORD)

	-- set be 0 (ignore that)
	read_byte(DWORD * 2)

	header.pallete_entry = read_byte(BYTE)

	-- ignore
	read_byte(BYTE * 3)

	header.number_color = read_byte(WORD)
	header.pixel_width = read_byte(BYTE)
	header.pixel_height = read_byte(BYTE)
	header.grid_x = read_byte(SHORT)
	header.grid_y = read_byte(SHORT)
	header.grid_width = read_byte(WORD)
	header.grid_height = read_byte(WORD)

	-- set be 0 (ignore that)
	read_byte(BYTE * 84)

	return header
end

local function grab_frame_header()
	local frame_header = {}

	frame_header.bytes_size = read_byte(DWORD)
	frame_header.magic_number = read_byte(WORD)

	if frame_header.magic_number ~= 0xF1FA then
		print("Corrupted file")
		return
	end

	local old_chunks = read_byte(WORD)

	frame_header.frame_duration = read_byte(WORD)

	-- set be 0 (ignore that)
	read_byte(BYTE * 2)

	-- if 0, use old chunks as chunks
	local new_chunks = read_byte(DWORD)

	if new_chunks == 0 then
		frame_header.chunks_number = old_chunks
	else
		frame_header.chunks_number = new_chunks
	end

	-- to the future
	frame_header.chunks = {}

	return frame_header
end

local function grab_color_profile()
	local color_profile = {}

	color_profile.type = read_byte(WORD)
	color_profile.uses_fixed_gama = read_byte(WORD)
	color_profile.fixed_game = read_byte(FIXED)

	-- set to 0 (ignore that)
	read_byte(BYTE * 8)

	if color_profile.type ~= 1 then
		print("No suported color profile, put it in RGB")
		return
	end

	return color_profile
end

local function grab_palette()
	local palette = {}

	palette.entry_size = read_byte(DWORD)
	palette.first_color = read_byte(DWORD)
	palette.last_color = read_byte(DWORD)
	palette.colors = {}

	-- set to 0 (ignore that)
	read_byte(BYTE * 8)

	for i = 1, palette.entry_size do
		local has_name = read_byte(WORD)

		palette.colors[i] = {
			color = {read_byte(BYTE), read_byte(BYTE), read_byte(BYTE), read_byte(BYTE)}
		}

		if has_name == 1 then
			palette.colors[i].name = read_string()
		end
	end

	return palette
end

local function grab_old_palette()
	local palette = {}

	palette.packets = read_byte(WORD)
	palette.colors_packet = {}

	for i = 1, palette.packets do
		palette.colors_packet[i] = {
			entries = read_byte(BYTE),
			number = read_byte(BYTE),
			colors = {}
		}

		for j = 1, palette.colors_packet[i].number do
			palette.colors_packet[i][j] = {read_byte(BYTE), read_byte(BYTE), read_byte(BYTE)}
		end
	end

	return palette
end

local function grab_layer()
	local layer = {}

	layer.flags = read_byte(WORD)
	layer.type = read_byte(WORD)
	layer.child_level = read_byte(WORD)
	layer.width = read_byte(WORD)
	layer.height = read_byte(WORD)
	layer.blend = read_byte(WORD)
	layer.opacity = read_byte(BYTE)

	-- set to 0 (ignore that)
	read_byte(BYTE * 3)

	layer.name = read_string()

	return layer
end

local function grab_cel(size)
	local cel = {}

	cel.layer_index = read_byte(WORD)
	cel.x = read_byte(WORD)
	cel.y = read_byte(WORD)
	cel.opacity_level = read_byte(BYTE)
	cel.type = read_byte(WORD)

	read_byte(BYTE * 7)

	if cel.type == 2 then
		cel.width = read_byte(WORD)
		cel.height = read_byte(WORD)
		cel.data = data:read(size - 26)
	end

	return cel
end

local function grab_tags()
	local tags = {}

	tags.number = read_byte(WORD)
	tags.tags = {}

	-- set to 0 (ignore that)
	read_byte(BYTE * 8)

	for i = 1, tags.number do
		tags.tags[i] = {
			from = read_byte(WORD),
			to = read_byte(WORD),
			direction = read_byte(BYTE),
			extra_byte = read_byte(BYTE),
			color = read_byte(BYTE * 3),
			skip_holder = read_byte(BYTE * 8),
			name = read_string()
		}
	end

	return tags
end

local function grab_slice()
	local slice = {}

	slice.key_numbers = read_byte(DWORD)
	slice.keys = {}
	slice.flags = read_byte(DWORD)

	-- reserved?
	read_byte(DWORD)

	slice.name = read_string()

	for i = 1, slice.key_numbers do
		slice.keys[i] = {
			frame = read_byte(DWORD),
			x = read_byte(DWORD),
			y = read_byte(DWORD),
			width = read_byte(DWORD),
			height = read_byte(DWORD)
		}

		if slice.flags == 1 then
			slice.keys[i].center_x = read_byte(DWORD)
			slice.keys[i].center_y = read_byte(DWORD)
			slice.keys[i].center_width = read_byte(DWORD)
			slice.keys[i].center_height = read_byte(DWORD)
		elseif slice.flags == 2 then
			slice.keys[i].pivot_x = read_byte(DWORD)
			slice.keys[i].pivot_y = read_byte(DWORD)
		end
	end

	return slice
end

local function grab_user_data()
	local user_data = {}

	user_data.flags = read_byte(DWORD)
	
	if user_data.flags == 1 then
		user_data.text = read_string()
	elseif user_data.flags == 2 then
		user_data.colors = read_byte(BYTE * 4)
	end

	return user_data
end

local function grab_chunk()
	local chunk = {}

	chunk.size = read_byte(DWORD)
	chunk.type = read_byte(WORD)

	if chunk.type == 0x2007 then
		chunk.data = grab_color_profile()
	elseif chunk.type == 0x2019 then
		chunk.data = grab_palette()
	elseif chunk.type == 0x0004 then
		chunk.data = grab_old_palette()
	elseif chunk.type == 0x2004 then
		chunk.data = grab_layer()
	elseif chunk.type == 0x2005 then
		chunk.data = grab_cel(chunk.size)
	elseif chunk.type == 0x2018 then
		chunk.data = grab_tags()
	elseif chunk.type == 0x2022 then
		chunk.data = grab_slice()
	elseif chunk.type == 0x2020 then
		chunk.data = grab_user_data()
	end

	return chunk
end

local function load_ase(src)
	data = io.open(src, "rb")

	local ase = {}
	ase.header = grab_header()
	ase.header.frames = {}

	for i = 1, ase.header.frames_number do
		ase.header.frames[i] = grab_frame_header()

		for j = 1, ase.header.frames[i].chunks_number do
			ase.header.frames[i].chunks[j] = grab_chunk()
		end
	end

	data.close()
	return ase
end

return load_ase