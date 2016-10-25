local Class = require 'class'
local Window = require 'window.window'

local Locals = Class({ __includes = Window})


function Locals:draw()

  Window.draw( self )

  local inf = self.ide.callstack:getinfo()

  if inf then

    local theme = self.theme

    local y = 0
    for k,v in pairs(inf.locals) do

      local text
      if type(v[2]) == 'string' then
        text = v[1] .. " = '" .. v[2] .. "'"
      else
        text = v[1] .. ' = ' .. tostring(v[2])
      end
      local bg = self.selected == k and theme.base2 or theme.bg

      -- line needs to wrap
      while #text > self.w do

        -- wrap at last whitespace or split line if needed
        local wrap = (text:sub(1,self.w+1):match('(.*)%s+[^%s]*')) or text:sub(1,self.w)

        self:printat(0,y,wrap,theme.fg,bg)
        y = y + 1
        text = text:sub(#wrap+1)
      end

      self:printat(0,y,text,theme.fg,bg)

      y = y + 1

      if type(v[2]) == 'table' and v.expanded == true then
        for kk,vv in pairs(v[2]) do
          local tt
          if type(vv) == 'function' then
            tt = kk .. '()'
          elseif type(vv) == 'table' then
            tt = kk .. ' = {}'
          else
            tt = kk .. ' = ' .. tostring(vv)
          end

          self:printat(2,y,tt,theme.fg,theme.base2)
          y =y + 1
        end
      end



    end

  end


end

return Locals
