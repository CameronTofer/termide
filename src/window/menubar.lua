local Class = require 'class'
local Window = require 'window.window'

local Menubar = Class({ __includes = Window})


function Menubar:draw()
  Window.draw(self)
  local x = 1
  for _,v in pairs(self.items) do
    self:printat(x,0,v.name)
    x = x + #v.name + 3
  end
end

function Menubar:mouseDown(mx,my)

  local x = 1
  for _,v in pairs(self.items) do
    local l = #v.name
    if mx >= x and mx <= x+l then
      v.action(self)
      break
    end

    x = x + l + 3
  end

end

return Menubar