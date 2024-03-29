{
    --------------------------------------------
    Filename: Il3897-MinimalDemo.spin
    Description: Demo of the IL3897 driver
        * minimal code example
    Author: Jesse Burt
    Copyright (c) 2024
    Started: Jan 2, 2024
    Updated: Jan 2, 2024
    See end of file for terms of use.
    --------------------------------------------
}
CON

    _clkmode    = xtal1+pll16x
    _xinfreq    = 5_000_000


OBJ

    fnt:    "font.5x8"
    disp:   "display.epaper.il3897" |   WIDTH=122, HEIGHT=250, ...
                                        CS=0, SCK=1, MOSI=2, DC=3, RST=4, BUSY=5

PUB main()

    disp.start()

    disp.preset_2p13_bw()                       ' Preset for 2.13" black & white

    repeat until disp.disp_rdy()                ' wait for the e-paper display to be ready

    disp.set_font(fnt.ptr(), fnt.setup())
    disp.bgcolor(disp.WHITE)                    ' set background color to white
    disp.clear()                                '   and clear the screen

    { draw some text }
    disp.pos_xy(0, 0)
    disp.fgcolor(disp.BLACK)                    ' set foreground color to black
    disp.strln(@"Testing 12345")

    { draw one pixel at the center of the screen }
    { disp.plot(x, y, color) }
    disp.plot(disp.CENTERX, disp.CENTERY, 1)

    { draw a box at the screen edges }
    { disp.box(x_start, y_start, x_end, y_end, color, filled) }
    disp.box(0, 0, disp.XMAX, disp.YMAX, 1, false)

    { The display is actually "drawn" to a buffer in Propeller RAM. Once you've completed all
        the drawing operations you want for the frame you're displaying, you must tell
        the driver to send the buffer to the display with show(): }
    disp.show()

    repeat

DAT
{
Copyright 2024 Jesse Burt

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and
associated documentation files (the "Software"), to deal in the Software without restriction,
including without limitation the rights to use, copy, modify, merge, publish, distribute,
sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or
substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT
NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM,
DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT
OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
}

