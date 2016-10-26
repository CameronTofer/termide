local termfx = require 'termfx'
local lxsh = require 'lxsh'
local Class = require 'oo'


local Window = Class()

function Window:__init( ide, name, theme )
  self.ide = ide
  self.name = name
  self.theme = theme or ide.theme
end

function Window:contains( x,y )
  return x >= self.x and x <= self.x + self.w and y >= self.y and y <= self.y + self.h
end

function Window:draw()
  local theme = self.theme

  termfx.attributes(theme.fg,theme.bg)
  termfx.rect(self.x,self.y,self.w,self.h,' ',theme.fg,theme.bg)

  if self.name then
    termfx.attributes(theme.base1,theme.bg)
    termfx.printat(self.x+self.w-#self.name,self.y+self.h-1,self.name)
  end

  self.contentHeight = 0
end

function Window:printat( x,y,text, fg,bg )

  if y >= self.contentHeight then
    self.contentHeight = y + 2
  end

  y = y - (self.contentTop or 0)
  if y >= 0 and y < self.h then
    termfx.attributes(fg,bg)
    termfx.printat(self.x + x,self.y + y,text,self.w-x)
  end

end


function Window:drawscroll()

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

end

function Window:mouseEvent( evt )

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

end

function Window:mouseDown( x,y )
  self.selected = (self.contentTop or 0) + y - self.y + 1
end

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


local Source = Window:extend()

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


local Callstack = Window:extend()

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

local Locals = Window:extend()

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


local Output = Window:extend()

function Output:draw()

  Window.draw(self)
  Window.wraplines(self,self.log)
  Window.drawscroll(self)

end

local Menubar = Window:extend()

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


local Termide = Class({

  themes =
  {
    solarized_dark =
    {
      base3   = 234,
      base2   = 235,
      base1   = 240,   -- optional emphasized content
      base0   = 241,   -- body text / default code / primary content
      base00    = 244,
      base01    = 245, --245,   -- comments / secondary content
      base02    = 254,   -- background highlights
      base03    = 230,   -- background
      yellow   = 136,
      orange   = 166,
      red      = 160,
      magenta  = 125,
      violet   =  61,
      blue     =  33,
      cyan     =  37,
      green    =  64,

      fg = 241, -- base0
      bg = 234, -- base3
    },

    solarized_light =
    {
      base03   = 234,
      base02   = 235,
      base01   = 240,   -- optional emphasized content
      base00   = 241,   -- body text / default code / primary content
      base0    = 244,
      base1    = 249, --245,   -- comments / secondary content
      base2    = 254,   -- background highlights
      base3    = 230,   -- background
      yellow   = 136,
      orange   = 166,
      red      = 160,
      magenta  = 125,
      violet   =  61,
      blue     =  33,
      cyan     =  37,
      green    =  64,

      fg = 244, -- base0
      bg = 230, -- base3
    },
  },

  Window = Window,
  Source = Source,
  Callstack = Callstack,
  Locals = Locals,
  Output = Output,
  Menubar = Menubar,

})


function Termide:splitH(full,left,right,ratio)
  left.x = full.x
  left.y = full.y
  left.w = math.floor(full.w * ratio )
  left.h = full.h

  right.x = left.x + left.w + 2
  right.y = full.y
  right.w = full.w - right.x
  right.h = full.h
  return left,right
end

function Termide:splitV(full,top,bottom,ratio)
  top.x = full.x
  top.y = full.y
  top.w = full.w
  top.h = math.floor(full.h * ratio)

  bottom.x = full.x
  bottom.y = top.y + top.h + 1
  bottom.w = full.w
  bottom.h = full.h - bottom.y
  return top,bottom
end


function Termide:__init( theme )
  self.theme = theme or self.themes.solarized_light
end

function Termide:resize( w,h, theme )

  self.theme = theme or self.theme

  -- create windows
  self.source = self.source or Source(self,'[Source]')
  self.callstack = self.callstack or Callstack(self,'[Callstack]')
  self.locals = self.locals or Locals(self,'[Locals]')
  self.output = self.output or Output(self,'[Output]')

  self.menubar = self.menubar or Menubar(self,'[menu]')
  self.menubar.items = self.menubar.items or
  {
    { name = 'Light', action = function()
      self:resize(termfx.width(),termfx.height(),self.themes.solarized_light)
    end},

    { name = 'Dark', action = function()
      self:resize(termfx.width(),termfx.height(),self.themes.solarized_dark)
    end},
  }

  -- arrange windows
  local top,bottom = self:splitV({x=2,y=3,w=w,h=h},{},{},2/3)
  self:splitH(top,self.source,self.callstack,2/3)
  self:splitH(bottom,self.output,self.locals,1/2)

  self.menubar.x = 2
  self.menubar.y = 1
  self.menubar.w = w-2
  self.menubar.h = 1

  self.windows = { self.menubar, self.source, self.callstack, self.locals, self.output }

  for _,v in pairs(self.windows) do
    v.theme = self.theme
  end

end

function Termide:draw()

  termfx.clear( self.theme.base0, self.theme.base2 )
  for _,w in pairs(self.windows) do
    w:draw()
  end
  termfx.present()

end

function Termide:debug()

  local ok, r = xpcall(function()

    self.callstack:update()

    repeat

      self:draw()


      local evt = termfx.pollevent()

      if evt.type == 'mouse' and evt.x and evt.y then

        -- termfx bug
        if evt.x < 0 then
          evt.x = 95 + (evt.x+161)
        end

        for _,w in pairs(self.windows) do
          if w:contains(evt.x,evt.y) then
            local r = w:mouseEvent(evt)
            if r then
              return r
            end
          end
        end

      elseif evt.type == 'key' then

        assert(evt.char ~= 'q')

        if why == 'breakpoint' then
          return
        end

      elseif evt.type == 'resize' then
        if evt.w > 80 and evt.h > 24 then
          self:resize(evt.w,evt.h)
        end
      end

    until evt.char == 'q'

    termfx.shutdown()


  end,function(err)

    -- error in debugger
    termfx.shutdown()
    print(debug.traceback(err))

  end)

  if ok == true then
    return r
  end

  os.exit()

end

function Termide:launchdebugger( filename )

  local ok,result = xpcall(function()

    termfx.init()
    termfx.inputmode(termfx.input.MOUSE)
    termfx.outputmode(termfx.output.COL256)

    self:resize( termfx.width(), termfx.height() )

    local env = setmetatable(
    {
      print = function(...)
        self.output.log = self.output.log or {}
        table.insert(self.output.log, table.concat({...},'\t'))
      end,
      debug = function()
        self:debug()
      end,
    },{ __index = _G})

    local main = loadfile(filename,'bt',env)

    --debug.sethook(function() self:debug() end,"",20000)

    main()

    xpcall(main,function(err)
      self:debug('error')
      return 'errorred'
    end)


  end, function(err)
    termfx.shutdown()
    print( debug.traceback(err) )
    return err
  end)

end





function Termide:run()

  local ok,result = xpcall(function()

    termfx.init()
    termfx.inputmode(termfx.input.MOUSE)
    termfx.outputmode(termfx.output.COL256)

    self:resize( termfx.width(), termfx.height() )

    repeat

      self:draw()

      local evt = termfx.pollevent()

      if evt.type == 'mouse' and evt.x and evt.y then

        -- termfx bug
        if evt.x < 0 then
          evt.x = 95 + (evt.x+161)
        end

        for _,w in pairs(self.windows) do
          if w:contains(evt.x,evt.y) then
            local r = w:mouseEvent(evt)
            if r then
              return r
            end
          end
        end

      elseif evt.type == 'key' then

        if evt.char == 'q' then
          break
        end

      elseif evt.type == 'resize' then
        if evt.w > 80 and evt.h > 24 then
          self:resize(evt.w,evt.h)
        end
      end

    until evt.char == 'q'

    termfx.shutdown()

  end, function(err)
    termfx.shutdown()
    print( debug.traceback(err) )
    return err
  end)

end

return Termide