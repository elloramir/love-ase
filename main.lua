Sprite = require "sprite"

function love.load()
	love.graphics.setDefaultFilter("nearest", "nearest")
	player = Sprite("player.ase")
	player:play("run")
end

function love.update(delta)
	player:update(delta)
end

function love.draw()
	player:draw(0, 0, 0, 10, 10)
end