local Class = require 'class'
local Window = require 'window.window'

local Output = Class({ __includes = Window})


function Output:draw()

  Window.draw(self)
  self:printat(3,3,'bitch town')

end

return Output