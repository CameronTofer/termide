local Termide = require 'termide'


local ide = Termide()


local windows =
{
  source = ide:Window({

  }),

  callstack = ide:Window({

  }),

  locals = ide:Window({

  }),

  output = ide:Window({

  })
}


local mywindow = ide:Window({
  draw = function( self )
    self:printat(1,1,"What's up ass dicks?")
  end,
})

function ide:resize( w,h, theme )

  self.theme = theme or self.theme
  self.mywindow = mywindow

end



ide:launchdebugger('a.lua')
print('done')