local Class = require 'class'
local Window = require 'window.window'

local Callstack = Class({ __includes = Window })

function Callstack:update()

  self.stack = {}
  for i=1,64 do
    local inf = debug.getinfo(i+3)
    if inf == nil then
      break
    end
    self.stack[i] = inf

    local locals = {}
    for j=1,100 do
      local k,v = debug.getlocal(i+3,j)
      if k == nil then
        break
      end
      table.insert(locals,{k,v})
    end

    if inf.func then
      for j=1,100 do
        local k, v = debug.getupvalue(inf.func, j)
        if not k then break end
        table.insert(locals,{k,v})
      end
    end

    self.stack[i].locals = locals
  end
  self.contentTop = 0

end


function Callstack:draw()

  Window.draw(self)

  if self.stack then

    local theme = self.theme

    for i,inf in pairs(self.stack) do
      local hl = i == self.selected and theme.base2 or theme.bg
      self:printat(1,i-1,(inf.name or (inf.short_src..':'..inf.currentline)),inf.what == 'C' and theme.base1 or theme.fg,hl)
    end
  end

  Window.drawscroll(self)

end

function Callstack:getinfo()

  if self.selected then
    return self.stack[self.contentTop + self.selected]
  end

end

function Callstack:mouseDown( ... )

  Window.mouseDown( self, ... )

  local source = self.ide.source
  local inf = self.stack[ self.contentTop + self.selected ]

  if inf and inf.short_src then
    source:view( inf.short_src, math.max(1,inf.currentline-1) )
    source.selected = inf.currentline
  end

end


return Callstack
