local Termide = require 'termide'


local ide = Termide()

--ide:launchdebugger('../examples/a.lua')

local MyWindow = ide.Window:extend()

function MyWindow:draw()
  self.super.draw(self)
  self:printat(1,1,"what's up ass dicks")
end

function ide:resize( w,h, theme )

  self.mywindow = self.mywindow or MyWindow(self,'[MyWindow]',theme)
  self.mywindow.x = 2
  self.mywindow.y = 2
  self.mywindow.w = w-2
  self.mywindow.h = h-2

  self.windows = {
    self.mywindow
  }

end



ide:run()