{
    --------------------------------------------
    Filename: IL3897-Demo.spin
    Author:
    Description:
    Copyright (c) 2021
    Started Feb 21, 2021
    Updated Feb 21, 2021
    See end of file for terms of use.
    --------------------------------------------
}

CON

    _clkmode    = cfg#_clkmode
    _xinfreq    = cfg#_xinfreq

' -- User-defined constants
    SER_BAUD    = 115_200
    LED         = cfg#LED1

    CS_PIN      = 4
    SCK_PIN     = 1
    MOSI_PIN    = 2
    RST_PIN     = 5
    DC_PIN      = 6
    BUSY_PIN    = 7

' --

    WIDTH       = 128
    HEIGHT      = 250
    BUFFSZ      = (WIDTH * HEIGHT) / 8

OBJ

    cfg : "core.con.boardcfg.flip"
    ser : "com.serial.terminal.ansi"
    time: "time"
    epd : "display.epaper.il3897.spi"
    fnt : "font.5x8"

VAR

    byte _disp_buffer[BUFFSZ]

PUB Main{} | x, y, s

    setup{}
    ser.printf3(string("size: %x  start: %x  end: %x\n"), BUFFSZ, @_disp_buffer, @_disp_buffer+BUFFSZ)
    epd.preset_2_13_bw{}
    clear

    epd.fgcolor(0)
    epd.bgcolor(1)
    epd.str(string("EPD 2.13''"))
    epd.box(0, 0, 121, 249, 0, false)
    epd.circle(61, 125, 40, 0, true)
    epd.update

    repeat

PUB Bitmap(p, sz)

    bytemove(@_disp_buffer, p, sz)

PUB Clear{}

    bytefill(@_disp_buffer, $ff, BUFFSZ)

PUB Plot(x, y, color)

    case color
        1:
            byte[@_disp_buffer][(x + y * WIDTH) / 8] |= $80 >> (x // 8)
        0:
            byte[@_disp_buffer][(x + y * WIDTH) / 8] &= !($80 >> (x // 8))
        -1:
            byte[@_disp_buffer][(x + y * WIDTH) / 8] ^= $80 >> (x // 8)
        other:
            return

PUB Setup{}

    ser.start(SER_BAUD)
    time.msleep(30)
    ser.clear{}
    ser.strln(string("Serial terminal started"))

    if epd.startx(CS_PIN, SCK_PIN, MOSI_PIN, RST_PIN, DC_PIN, BUSY_PIN, WIDTH, HEIGHT, @_disp_buffer)
        epd.fontaddress(fnt.baseaddr{})
        epd.fontscale(1)
        epd.fontsize(6, 8)
        ser.strln(string("IL3897 driver started"))
    else
        ser.strln(string("IL3897 driver failed to start - halting"))
        repeat

DAT
{
    --------------------------------------------------------------------------------------------------------
    TERMS OF USE: MIT License

    Permission is hereby granted, free of charge, to any person obtaining a copy of this software and
    associated documentation files (the "Software"), to deal in the Software without restriction, including
    without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
    copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the
    following conditions:

    The above copyright notice and this permission notice shall be included in all copies or substantial
    portions of the Software.

    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT
    LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
    IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
    WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
    SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
    --------------------------------------------------------------------------------------------------------
}
