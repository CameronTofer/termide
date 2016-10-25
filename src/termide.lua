local Class = require 'class'
local Source = require 'window.source'
local Callstack = require 'window.callstack'
local Locals = require 'window.locals'
local Output = require 'window.output'
local Menubar = require 'window.menubar'
local termfx = require 'termfx'


local Termide = Class({

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
    base1    = 245, --245,   -- comments / secondary content
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

  init = function( self,layout,theme )

    self.resize = self['layout_' .. (layout or 'simple')]
    self.theme = theme or self.solarized_dark

  end,
})

local function splitH(full,left,right,ratio)
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

local function splitV(full,top,bottom,ratio)
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

function Termide:layout_simple( w,h, theme )

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
      self:resize(termfx.width(),termfx.height(),self.solarized_light)
    end},

    { name = 'Dark', action = function()
      self:resize(termfx.width(),termfx.height(),self.solarized_dark)
    end},
  }

  -- arrange windows
  local top,bottom = splitV({x=2,y=3,w=w,h=h},{},{},2/3)
  splitH(top,self.source,self.callstack,2/3)
  splitH(bottom,self.output,self.locals,1/2)

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
        print(...)
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

return Termide
