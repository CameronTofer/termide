local Class = require 'class'
local Window = require 'window.window'

local Output = Class({ __includes = Window})


function Output:draw()

  Window.draw(self)
  Window.wraplines(self,self.log)
  Window.drawscroll(self)

end

return Output