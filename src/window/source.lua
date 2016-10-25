local Class = require 'class'
local Window = require 'window.window'
local lxsh = require 'lxsh'

local Source = Class({ __includes = Window})

function Source:draw()

  Window.draw(self)
  if self.source then
    Window.wraptokens(self, self.source )
  end
  Window.drawscroll(self)

end

function Source:loadsource( filename )

  if not self.cache then
    self.cache = {}
  end

  if self.cache[ filename ] then
    return self.cache[ filename ]
  end

  local f = io.open(filename, "rb")
  if not f then
    return
  end

  local content = f:read("*all")
  content = content:gsub('\r','')
  f:close()

  local tokens = {}
  local keywords = ' break do else elseif end for function if in local repeat return then until while '

  for kind, text, line, col in lxsh.lexers.lua.gmatch(content) do
    if kind ~= 'whitespace' then
      if string.find(keywords,' '..text..' ',1,true) then
        kind = 'keyword'
      end
      table.insert(tokens,{kind,text,line,col})
    end
  end

  self.cache[ filename ] = tokens

  return self.cache[ filename ]

end

function Source:view( filename )

  self.source = self:loadsource( filename )
  self.contentTop = nil
  self.contentHeight = nil
  self.selected = nil

end


return Source