local Class = require 'class'
local termfx = require 'termfx'

local Window = Class(
{
--====--
  init = function( self, ide, name, theme )
--====--
    self.ide = ide
    self.theme = theme or ide.theme
    self.name = name
  end,

--========--
  contains = function( self, x,y )
--========--
    return x >= self.x and x <= self.x + self.w and y >= self.y and y <= self.y + self.h
  end,

--====--
  draw = function( self )
--====--

    local theme = self.theme

    termfx.attributes(theme.fg,theme.bg)
    termfx.rect(self.x,self.y,self.w,self.h,' ',theme.fg,theme.bg)

    if self.name then
      termfx.attributes(theme.base1,theme.bg)
      termfx.printat(self.x+self.w-#self.name,self.y+self.h-1,self.name)
    end

    self.contentHeight = 0

  end,

--=======--
  printat = function( self, x,y,text, fg,bg )
--=======--

  if y >= self.contentHeight then
    self.contentHeight = y + 2
  end

  y = y - (self.contentTop or 0)
  if y >= 0 and y < self.h then
    termfx.attributes(fg,bg)
    termfx.printat(self.x + x,self.y + y,text,self.w-x)
  end

end,


--==========--
  drawscroll = function( self )
--==========--

    if self.contentHeight and (self.contentHeight > self.h+1) then

      local theme = self.theme

      local dy = self.h / self.contentHeight
      local ds = math.floor((self.contentTop or 0) * dy)
      local de = ds + math.floor(self.h * dy)

      termfx.attributes(theme.fg,theme.base1)
      for sy = ds,de do
        termfx.printat(self.x + self.w, self.y + sy, ' ')
      end
    end

  end,

--==========--
  mouseEvent = function( self, evt )
--==========--

    if evt.key == termfx.key.MOUSE_WHEEL_DOWN then

      if self.contentHeight > self.h then
        self.contentTop = math.min( (self.contentTop or 0) + 1, self.contentHeight - self.h )
      end

    elseif evt.key == termfx.key.MOUSE_WHEEL_UP then

      if self.contentHeight > self.h then
        self.contentTop = math.max( 0, (self.contentTop or 0) - 1)
      end

    elseif evt.key ~= termfx.key.MOUSE_RELEASE then

      return self:mouseDown(evt.x,evt.y)

    end

  end,


--=========--
  mouseDown = function( self, x,y )
--=========--
    self.selected = (self.contentTop or 0) + y - self.y + 1
  end,


})


function Window:wraptokens(tokens, y, lineNumber, tokenStart, tokenEnd, lineSelected)

  local theme = self.theme

  local fg =
  {
    ['comment']     = theme.base1,
    ['constant']    = theme.green,
    ['error']       = theme.magenta,
    ['identifier']  = theme.base00,
    ['keyword']     = theme.magenta + termfx.format.BOLD,
    ['number']      = theme.base00 + termfx.format.BOLD,
    ['operator']    = theme.violet + termfx.format.BOLD,
    ['string']      = theme.green,
  }
  local bg =
  {
    --['string']      = 155, --theme.base2,
    --['comment']     = 194,
  }

  local sx = 4
  local sc = 0
  local wx = 0

  local w = self.w

  y = y or -1
  lineNumber = lineNumber or 0
  tokenStart = tokenStart or 1
  tokenEnd = tokenEnd or #tokens
  lineSelected = lineSelected or self.selected


  for i=tokenStart,tokenEnd do
    local token = tokens[i]
    local kind,text,line,col = unpack(token)

    -- starting a new line
    for l=lineNumber+1,line do
      lineNumber = l
      y = y + 1
      local hl = lineSelected == lineNumber and theme.red or theme.bg
      self:printat(0,y,lineNumber,theme.base1,hl)
      sc = 0
      sx = 4
      wx = sx + col + 2
    end

    -- length of token
    local l = #text
    local tx = sx + (col-sc)

    -- token needs to wrap
    while tx + l > w do

      -- token needs to split
      if wx + l > w then

        local n = w - tx
        local ltext = string.sub(text,1,n)
        self:printat(tx,y,ltext,fg[kind],bg[kind] or theme.bg)

        n = n + 1
        text = string.sub(text,n)
        col = col + n
        l = #text
      end

      y = y + 1
      sc = col
      sx = wx
      tx = sx
    end

    self:printat(tx,y,text,fg[kind],bg[kind] or theme.bg)

  end

  return y

end


function Window:wraplines(content)

  if not content then
    return
  end

  local theme = self.theme

  local y = 0
  local w = self.w - 4

  if self.target then
    self.contentTop = #self.source
  end

  for lineNumber,text in pairs(content) do

    self:printat(0,y,lineNumber,theme.base1,theme.bg)

    -- line needs to wrap
    while #text > w do

      -- wrap at last whitespace or split line if needed
      local wrap = (text:sub(1,w+1):match('(.*)%s+[^%s]*')) or text:sub(1,w)

      self:printat(4,y,wrap,theme.fg,theme.bg)
      y = y + 1
      text = text:sub(#wrap+1)
    end

    self:printat(4,y,text,theme.fg,theme.bg)

    y = y + 1

  end

end


return Window