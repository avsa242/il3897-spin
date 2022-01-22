{
    --------------------------------------------
    Filename: display.epaper.il3897.spi.spin
    Author: Jesse Burt
    Description: Driver for IL3897/SSD1675 AM E-Paper display
        controller
    Copyright (c) 2022
    Started Feb 21, 2021
    Updated Jan 21, 2022
    See end of file for terms of use.
    --------------------------------------------
}
#define IL38xx
#define MEMMV_NATIVE bytemove
#include "lib.gfx.bitmap.spin"

CON

' Colors
    BLACK           = 0
    WHITE           = $FF
    INVERT          = -1

    MAX_COLOR       = 1
    BYTESPERPX      = 1

' Border waveform control
    GS_TRANS        = %00
    FIXEDLEV        = %01
    VCOM            = %10
    HIZ             = %11

    VSS             = %00
    VSH1            = %01
    VSL             = %10
    VSH2            = %11

    FLWLUT_VCOMRED  = 0
    FLWLUT          = 1

    LUT0            = %00
    LUT1            = %01
    LUT2            = %10
    LUT3            = %11

' Display addressing modes
    HORIZ           = 0
    VERT            = 1
    YD_XD           = %00
    YD_XI           = %01
    YI_XD           = %10
    YI_XI           = %11

VAR

    long _ptr_drawbuffer
    long _CS, _RST, _DC, _BUSY
    word _buff_sz
    word _bytesperln
    byte _disp_width, _disp_height, _disp_xmax, _disp_ymax

    ' shadow registers
    byte _brd_wvf_ctrl, _data_entr_mode, _drv_out_ctrl[3]

OBJ

    spi : "com.spi.fast-nocs"                   ' PASM SPI engine (20MHz/10MHz)
    core: "core.con.il3897"                     ' hw-specific low-level const's
    time: "time"                                ' Basic timing functions

PUB Null{}
' This is not a top-level object

PUB Startx(CS_PIN, SCK_PIN, MOSI_PIN, RST_PIN, DC_PIN, BUSY_PIN, WIDTH, HEIGHT, PTR_DISPBUFF): status
' Start using custom IO pins
    if lookdown(CS_PIN: 0..31) and lookdown(SCK_PIN: 0..31) and {
}   lookdown(MOSI_PIN: 0..31) and lookdown(RST_PIN: 0..31) and {
}   lookdown(DC_PIN: 0..31) and lookdown(BUSY_PIN: 0..31)
        if (status := spi.init(SCK_PIN, MOSI_PIN, -1, core#SPI_MODE))
            time.usleep(core#T_POR)             ' wait for device startup
            dira[DC_PIN] := 1
            outa[RST_PIN] := 1
            dira[RST_PIN] := 1
            dira[BUSY_PIN] := 0
            outa[CS_PIN] := 1
            dira[CS_PIN] := 1

            _CS := CS_PIN
            longmove(@_RST, @RST_PIN, 3)
            address(PTR_DISPBUFF)
            _bytesperln := (BYTESPERPX * WIDTH)
            _disp_width := WIDTH
            if (_disp_width // 8)               ' round up width to next
                repeat                          ' multiple of 8 so alignment
                    _disp_width++               ' is correct
                until (_disp_width // 8) == 0
            _disp_height := HEIGHT
            _disp_xmax := _disp_width-1
            _disp_ymax := _disp_height-1
            _buff_sz := ((_disp_width/8) * HEIGHT)

            return
    ' if this point is reached, something above failed
    ' Re-check I/O pin assignments, bus speed, connections, power
    ' Lastly - make sure you have at least one free core/cog
    return FALSE

PUB Stop{}
' Stop SPI engine, float I/O pins, and clear variable space
    spi.deinit{}
    dira[_DC] := 0
    dira[_RST] := 0
    dira[_BUSY] := 0
    longfill(@_ptr_drawbuffer, 0, 4)
    wordfill(@_buff_sz, 0, 2)
    bytefill(@_disp_width, 0, 4)

PUB Defaults{}
' Factory default settings
    reset{}

PUB Preset_2_13_BW{}
' Presets for 2.13" BW E-ink panel, 122x250
    repeat until displayready{}
    reset{}
    repeat until displayready{}

    analogblkctrl{}
    digblkctrl{}
    gatestartpos(0)
    displaylines(250)
    gatefirstchan(0)
    interlaced(false)
    mirrorv(false)
    addrmode(HORIZ)
    addrctrmode(YI_XI)

    displaybounds(0, 0, 121, 249)

    bordermode(HIZ)
    bordervbdlev(VSS)
    bordergstctrl(FLWLUT_VCOMRED)
    bordergstrans(LUT0)

    vcomvoltage(2_125)
    gatevoltage(_lut_2p13_bw_full[70])
    sourcevoltage(_lut_2p13_bw_full[71], _lut_2p13_bw_full[72], _lut_2p13_bw_full[73])
    dummylineper(_lut_2p13_bw_full[74])
    gatelinewidth(_lut_2p13_bw_full[75])
    writelut(@_lut_2p13_bw_full)
    displaypos(0, 0)
    repeat until displayready{}

PUB Address(ptr_drawbuff)
' Set pointer to display/frame buffer
    case ptr_drawbuff
        4..$7fff-_buff_sz:
            _ptr_drawbuffer := ptr_drawbuff
        other:
            return _ptr_drawbuffer

PUB AddrCtrMode(mode): curr_mode
' Set address increment/decrement mode
'   Valid values:
'       YD_XD (%00): Y-decrement, X-decrement
'       YD_XI (%01): Y-decrement, X-increment
'       YI_XD (%10): Y-increment, X-decrement
'      *YI_XI (%11): Y-increment, X-increment
'   Any other value returns the current (cached) setting
    curr_mode := _data_entr_mode
    case mode
        YD_XD, YD_XI, YI_XD, YI_XI:
        other:
            return (curr_mode & core#ID_BITS)

    mode := ((curr_mode & core#ID_MASK) | mode)
    if (mode == curr_mode)                      ' no change to shadow reg;
        return                                  ' don't bother writing
    else
        _data_entr_mode := mode
    writereg(core#DATA_ENT_MD, 1, @_data_entr_mode)

PUB AddrMode(mode): curr_mode
' Set display addressing mode
'   Valid values:
'      *HORIZ (0)
'       VERT (1)
'   Any other value returns the current (cached) setting
    curr_mode := _data_entr_mode
    case mode
        HORIZ, VERT:
            mode <<= core#AM
        other:
            return ((curr_mode >> core#AM) & 1)

    mode := ((curr_mode & core#AM_MASK) | mode)
    if (mode == curr_mode)                      ' no change to shadow reg;
        return                                  ' don't bother writing
    else
        _data_entr_mode := mode
    writereg(core#DATA_ENT_MD, 1, @_data_entr_mode)

PUB AnalogBlkCtrl{} | tmp
' Analog Block control
    tmp := $54
    writereg(core#ANLG_BLK_CTRL, 1, @tmp)

PUB BorderGSTCtrl(mode): curr_mode
' Set border waveform GS transition mode
'   Valid values:
'       FLWLUT_VCOMRED (0)
'       FLWLUT (1)
'   Any other value returns the current (cached) setting
    curr_mode := _brd_wvf_ctrl
    case mode
        FLWLUT_VCOMRED, FLWLUT:
            mode <<= core#GSTRC
        other:
            return ((curr_mode >> core#GSTRC) & 1)

    mode := ((curr_mode & core#GSTRC_MASK) | mode)
    if (mode == curr_mode)                      ' no change to shadow reg;
        return                                  ' don't bother writing
    else
        _brd_wvf_ctrl := mode
    writereg(core#BRD_WV_CTRL, 1, @_brd_wvf_ctrl)

PUB BorderGSTrans(trans): curr_trans
' Set border waveform transition
    curr_trans := _brd_wvf_ctrl
    case trans
        LUT0..LUT3:
        other:
            return (curr_trans & core#GSTRS_BITS)

    trans := ((curr_trans & core#GSTRS_MASK) | trans)
    if (trans == curr_trans)                    ' no change to shadow reg;
        return                                  ' don't bother writing
    else
        _brd_wvf_ctrl := trans
    writereg(core#BRD_WV_CTRL, 1, @_brd_wvf_ctrl)

PUB BorderMode(mode): curr_mode
' Set border waveform VBD option
'   Valid values:
'       GS_TRANS (%00)
'       FIXEDLEV (%01)
'       VCOM (%10)
'       HIZ (%11)
'   Any other value returns the current (cached) setting
    curr_mode := _brd_wvf_ctrl
    case mode
        GS_TRANS, FIXEDLEV, VCOM, HIZ:
            mode << core#VBDOPT
        other:
            return ((curr_mode >> core#VBDOPT) & core#VBDOPT_BITS)

    mode := ((curr_mode & core#VBDOPT_MASK) | mode)
    if (mode == curr_mode)                      ' no change to shadow reg;
        return                                  ' don't bother writing
    else
        _brd_wvf_ctrl := mode
    writereg(core#BRD_WV_CTRL, 1, @_brd_wvf_ctrl)

PUB BorderVBDLev(level): curr_lev
' Set border fixed VBD level
'   Valid values:
'       VSS (%00)
'       VSH1 (%01)
'       VSL (%10)
'       VSH2 (%11)
'   Any other value returns the current (cached) setting
    curr_lev := _brd_wvf_ctrl
    case level
        VSS, VSH1, VSL, VSH2:
            level <<= core#VBDLVL
        other:
            return ((curr_lev >> core#VBDLVL) & core#VBDLVL_BITS)

    level := ((curr_lev & core#VBDLVL_MASK) | level)
    if (level == curr_lev)                      ' no change to shadow reg;
        return                                  ' don't bother writing
    else
        _brd_wvf_ctrl := level
    writereg(core#BRD_WV_CTRL, 1, @_brd_wvf_ctrl)

PUB DigBlkCtrl{} | tmp
' Digital Block control
    tmp := $3b
    writereg(core#DIGI_BLK_CTRL, 1, @tmp)

PUB DisplayBounds(sx, sy, ex, ey) | tmpx, tmpy
' Set drawable display region for subsequent drawing operations
'   Valid values:
'       sx, ex: 0..121
'       sy, ey: 0..249
    tmpx.byte[0] := sx / 8
    tmpx.byte[1] := ex / 8

    tmpy.byte[0] := sy.byte[0]
    tmpy.byte[1] := sy.byte[1]
    tmpy.byte[2] := ey.byte[0]
    tmpy.byte[3] := ey.byte[1]

    writereg(core#RAM_X_WIND, 2, @tmpx)
    writereg(core#RAM_Y_WIND, 4, @tmpy)

PUB DisplayLines(lines): curr_lines
' Set display visible lines
'   Valid values: 1..296
'   Any other value returns the current (cached) setting
    curr_lines.byte[0] := _drv_out_ctrl[0]
    curr_lines.byte[1] := _drv_out_ctrl[1]
    case lines
        1..296:
            lines -= 1
        other:
            return (curr_lines + 1)

    if (lines == curr_lines)                    ' no change to shadow reg;
        return                                  ' don't bother writing
    else
        _drv_out_ctrl[0] := lines.byte[0]
        _drv_out_ctrl[1] := lines.byte[1]
        writereg(core#DRV_OUT_CTRL, 3, @_drv_out_ctrl)

PUB DisplayPos(x, y) | tmp
' Set position for subsequent drawing operations
'   Valid values:
'       x: 0..121
'       y: 0..249
    writereg(core#RAM_X, 1, @x)
    writereg(core#RAM_Y, 2, @y)

PUB DisplayReady{}: flag
' Flag indicating display is ready to accept commands
    return (ina[_BUSY] == 0)

PUB DispUpdateCtrl2{} | tmp

    tmp := $c7
    writereg(core#DISP_UP_CTRL2, 1, 0)

PUB DummyLinePer(ln_per)

    writereg(core#DUMMY_LN_PER, 1, @ln_per)

PUB GateFirstChan(ch): curr_ch
' Set first output gate
'   Valid values:
'       0: G0 first channel; output sequence is G0, G1, G2, G3...
'       1: G1 first channel; output sequence is G1, G0, G3, G2...
'   Any other value returns the current (cached) setting
    curr_ch := _drv_out_ctrl[2]
    case ch
        0, 1:
            ch <<= core#GD
        other:
            return ((curr_ch >> core#GD) & 1)

    ch := ((curr_ch & core#GD_MASK) | ch)
    if (ch == curr_ch)
        return
    else
        _drv_out_ctrl[2] := ch
        writereg(core#DRV_OUT_CTRL, 3, @_drv_out_ctrl)

PUB GateLineWidth(ln_wid)

    writereg(core#GATE_LN_WID, 1, @ln_wid)

PUB GateStartPos(row)

    writereg(core#GATE_ST_POS, 2, @row)

PUB GateVoltage(volts)

    writereg(core#GATE_DRV_CTRL, 1, @volts)

PUB Interlaced(state): curr_state
' Alternate direction of every other display line
'   Valid values: TRUE (-1 or 1), FALSE (0)
'   Any other value returns the current (cached) setting
    curr_state := _drv_out_ctrl[2]
    case ||(state)
        0, 1:
            state := ||(state) << core#SM
        other:
            return (((curr_state >> core#SM) & 1) == 1)

    state := ((curr_state & core#SM_MASK) | state)
    if (state == curr_state)
        return
    else
        _drv_out_ctrl[2] := state
        writereg(core#DRV_OUT_CTRL, 3, @_drv_out_ctrl)

PUB MasterAct{}

    writereg(core#MASTER_ACT, 0, 0)

PUB MirrorV(state): curr_state  'XXX not functional yet
' Mirror display, vertically
'   Valid values: TRUE (-1 or 1), FALSE (0)
'   Any other value returns the current (cached) setting
    curr_state := _drv_out_ctrl[2]
    case ||(state)
        0, 1:
            state := ||(state) << core#TB
        other:
            return (((curr_state >> core#TB) & 1) == 1)

    state := ((curr_state & core#TB_MASK) | state)
    if (state == curr_state)
        return
    else
        _drv_out_ctrl[2] := state
        writereg(core#DRV_OUT_CTRL, 3, @_drv_out_ctrl)

PUB Reset{}
' Reset the device
    if (lookdown(_RST: 0..31))                  ' only touch the reset pin
        outa[_RST] := 0                         '   if it's defined
        time.msleep(200)
        outa[_RST] := 1
        time.msleep(200)
    else                                        ' otherwise, just perform
        writereg(core#SWRESET, 0, 0)            '   soft-reset
        time.usleep(core#T_POR)
    repeat until displayready{}

PUB SourceVoltage(vsh1, vsh2, vsl) | tmp

    tmp.byte[0] := vsh1
    tmp.byte[1] := vsh2
    tmp.byte[2] := vsl
    writereg(core#SRC_DRV_CTRL, 3, @tmp)

PUB Update{} | x, y
' Send the draw buffer to the display
    writereg(core#WR_RAM_BW, _buff_sz, _ptr_drawbuffer)

    dispupdatectrl2{}
    masteract{}
    writereg(core#NOOP, 0, 0)

    repeat until displayready{}

PUB VCOMVoltage(volts) | tmp
' Set VCOM voltage level, in millivolts
    case volts
        -3_000..-0_200:
            volts := volts / 25
        other:
            return
    writereg(core#WR_VCOM, 1, @volts)

PUB WriteLUT(ptr_lut)
' Write display waveform lookup table
'   NOTE: The data pointed to must be exactly 70 bytes
    writereg(core#WR_LUT, 70, ptr_lut)

PRI writeReg(reg_nr, nr_bytes, ptr_buff)
' Write nr_bytes to the device from ptr_buff
    case reg_nr
        core#WR_RAM_BW:
            outa[_DC] := 0
            outa[_CS] := 0
            spi.wr_byte(reg_nr)
            outa[_DC] := 1
            spi.wrblock_lsbf(ptr_buff, nr_bytes)
            outa[_CS] := 1
            return
        core#SWRESET, core#DISP_UP_CTRL2, core#MASTER_ACT:
            outa[_DC] := 0
            outa[_CS] := 0
            spi.wr_byte(reg_nr)
            outa[_CS] := 1
            return
        core#NOOP:
            outa[_DC] := 0
            outa[_CS] := 0
            spi.wr_byte(reg_nr)
            outa[_CS] := 1
            return
        $01, $03, $04, $0C, $0F, $10, $11, $14, $15, $1A, $1C, {
}       $26, $28, $29, $2C, $31, $32, $3A..$3C, $41, $44..$47, $4E, $4F, $74, {
}       $7E, $7F:
            outa[_DC] := 0
            outa[_CS] := 0
            spi.wr_byte(reg_nr)

            outa[_DC] := 1
            spi.wrblock_lsbf(ptr_buff, nr_bytes)
            outa[_CS] := 1
        other:
            return

DAT

' LUT waveform data
    _lut_2p13_bw_full
    '35
    byte    $80, $60, $40, $00, $00, $00, $00   ' LUT0: BB:     VS 0 ~7
    byte    $10, $60, $20, $00, $00, $00, $00   ' LUT1: BW:     VS 0 ~7
    byte    $80, $60, $40, $00, $00, $00, $00   ' LUT2: WB:     VS 0 ~7
    byte    $10, $60, $20, $00, $00, $00, $00   ' LUT3: WW:     VS 0 ~7
    byte    $00, $00, $00, $00, $00, $00, $00   ' LUT4: VCOM:   VS 0 ~7

    '35
    byte    $03, $03, $00, $00, $02             ' TP0 A~D RP0
    byte    $09, $09, $00, $00, $02             ' TP1 A~D RP1
    byte    $03, $03, $00, $00, $02             ' TP2 A~D RP2
    byte    $00, $00, $00, $00, $00             ' TP3 A~D RP3
    byte    $00, $00, $00, $00, $00             ' TP4 A~D RP4
    byte    $00, $00, $00, $00, $00             ' TP5 A~D RP5
    byte    $00, $00, $00, $00, $00             ' TP6 A~D RP6

    '6
    byte    $15, $41, $A8, $32, $30, $0A        ' GDC, SDC[0..2], DL, GT

    _lut_2p13_bw_partial

    byte    $00, $00, $00, $00, $00, $00, $00   ' LUT0: BB:     VS 0 ~7
    byte    $80, $00, $00, $00, $00, $00, $00   ' LUT1: BW:     VS 0 ~7
    byte    $40, $00, $00, $00, $00, $00, $00   ' LUT2: WB:     VS 0 ~7
    byte    $00, $00, $00, $00, $00, $00, $00   ' LUT3: WW:     VS 0 ~7
    byte    $00, $00, $00, $00, $00, $00, $00   ' LUT4: VCOM:   VS 0 ~7

    byte    $0A, $00, $00, $00, $00             ' TP0 A~D RP0
    byte    $00, $00, $00, $00, $00             ' TP1 A~D RP1
    byte    $00, $00, $00, $00, $00             ' TP2 A~D RP2
    byte    $00, $00, $00, $00, $00             ' TP3 A~D RP3
    byte    $00, $00, $00, $00, $00             ' TP4 A~D RP4
    byte    $00, $00, $00, $00, $00             ' TP5 A~D RP5
    byte    $00, $00, $00, $00, $00             ' TP6 A~D RP6

    byte    $15, $41, $A8, $32, $30, $0A        ' GDC, SDC[0..2], DL, GT

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
