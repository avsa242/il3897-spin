{
---------------------------------------------------------------------------------------------------
    Filename:       display.epaper.il3897.spin
    Description:    Driver for IL3897/SSD1675 active-matrix E-Paper display controller
    Author:         Jesse Burt
    Started:        Feb 21, 2021
    Updated:        Jan 28, 2024
    Copyright (c) 2024 - See end of file for terms of use.
---------------------------------------------------------------------------------------------------
}

#define 1BPP
#define MEMMV_NATIVE bytemove
#include "graphics.common.spinh"
#ifdef GFX_DIRECT
#   error "GFX_DIRECT not supported by this driver"
#endif

CON

    { -- default I/O settings; these can be overridden in the parent object }
    { display dimensions }
    WIDTH           = 128
    HEIGHT          = 296

    { SPI }
    CS              = 0
    SCK             = 1
    MOSI            = 2
    DC              = 3
    RST             = 4
    BUSY            = 5
    ' --

    XMAX            = WIDTH-1
    YMAX            = HEIGHT-1
    CENTERX         = WIDTH/2
    CENTERY         = HEIGHT/2
    BYTESPERLN      = WIDTH * BYTESPERPX
    BUFF_SZ         = ((WIDTH + 6) * HEIGHT) / 8


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

    BRD_VSS         = %00
    BRD_VSH1        = %01
    BRD_VSL         = %10
    BRD_VSH2        = %11

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

' Source drive voltage control
    VSH1            = 0
    VSH2            = 1
    VSL             = 2

' Waveform LUT offsets
    WV_LUT0         = 0
    WV_LUT1         = 7
    WV_LUT2         = 14
    WV_LUT3         = 21
    WV_LUT4         = 28
    WV_TP0          = 35
    WV_TP1          = 40
    WV_TP2          = 45
    WV_TP3          = 50
    WV_TP4          = 55
    WV_TP5          = 60
    WV_TP6          = 65

    GDC             = 70
    SDC0            = 71
    SDC1            = 72
    SDC2            = 73
    DL              = 74
    GT              = 75


VAR

    long _CS, _RST, _DC, _BUSY

    ' shadow registers
    byte _brd_wvf_ctrl, _data_entr_mode, _drv_out_ctrl[3], _src_drv_volt[3]
    byte _gate_drv_volt
    byte _framebuffer[BUFF_SZ]

OBJ

    spi : "com.spi.20mhz"                       ' PASM SPI engine
    core: "core.con.il3897"                     ' HW-specific constants
    time: "time"                                ' Basic timing functions

PUB null{}
' This is not a top-level object

PUB start(): status
' Start the driver using default I/O settings
    return startx(CS, SCK, MOSI, RST, DC, BUSY, WIDTH, HEIGHT, @_framebuffer)

PUB startx(CS_PIN, SCK_PIN, MOSI_PIN, RST_PIN, DC_PIN, BUSY_PIN, DISP_W, DISP_H, ptr_fb): status
' Start using custom IO pins
    if ( lookdown(CS_PIN: 0..31) and lookdown(SCK_PIN: 0..31) and ...
        lookdown(MOSI_PIN: 0..31) and lookdown(RST_PIN: 0..31) and ...
        lookdown(DC_PIN: 0..31) and lookdown(BUSY_PIN: 0..31) )
        if (status := spi.init(SCK_PIN, MOSI_PIN, -1, core#SPI_MODE))
            time.usleep(core#T_POR)             ' wait for device startup
            dira[DC_PIN] := 1
            dira[BUSY_PIN] := 0
            outa[CS_PIN] := 1
            dira[CS_PIN] := 1

            _CS := CS_PIN
            longmove(@_RST, @RST_PIN, 3)
            set_address(ptr_fb)
            if (DISP_W // 8)               ' round up width to next
                repeat                          ' multiple of 8 so alignment
                    DISP_W++               ' is correct
                until (DISP_W // 8) == 0
            set_dims(DISP_W, DISP_H)
            _buff_sz := BUFF_SZ

            return
    ' if this point is reached, something above failed
    ' Re-check I/O pin assignments, bus speed, connections, power
    ' Lastly - make sure you have at least one free core/cog
    return FALSE

PUB stop{}
' Stop SPI engine, float I/O pins, and clear variable space
    spi.deinit{}
    dira[_CS] := 0
    dira[_DC] := 0
    dira[_RST] := 0
    dira[_BUSY] := 0
    longfill(@_ptr_drawbuffer, 0, 4)
    wordfill(@_buff_sz, 0, 2)
    bytefill(@_disp_width, 0, 4)

PUB defaults{}
' Factory default settings
    reset{}

PUB preset_2p13_bw{}
' Presets for 2.13" BW E-ink panel, 122x250
    repeat until disp_rdy{}
    reset{}
    repeat until disp_rdy{}

    analog_blk_ctrl{}
    dig_blk_ctrl{}
    gate_start_pos(0)
    disp_lines(250)
    gate_first_chan(0)
    interlace_ena(false)
    mirror_v(false)
    addr_mode(HORIZ)
    addr_ctr_mode(YI_XI)

    draw_area(0, 0, 121, 249)

    border_mode(HIZ)
    border_vbd_lev(BRD_VSS)
    border_gst_mode(FLWLUT_VCOMRED)
    border_gst(LUT0)

    vcom_voltage(2_125)
    gate_high_voltage(19_000)
    vsh1_voltage(15_000)
    vsh2_voltage(5_000)
    vsl_voltage(-15_000)

    dummy_line_per(_lut_2p13_bw_full[74])
    gate_line_width(_lut_2p13_bw_full[75])
    wr_lut(@_lut_2p13_bw_full)
    disp_pos(0, 0)
    repeat until disp_rdy{}

PUB addr_ctr_mode(mode): curr_mode
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

PUB addr_mode(mode): curr_mode
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

PUB analog_blk_ctrl{} | tmp
' Analog Block control
    tmp := $54
    writereg(core#ANLG_BLK_CTRL, 1, @tmp)

PUB border_gst_mode(mode): curr_mode
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

PUB border_gst(trans): curr_trans
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

PUB border_mode(mode): curr_mode
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
            mode <<= core#VBDOPT
        other:
            return ((curr_mode >> core#VBDOPT) & core#VBDOPT_BITS)

    mode := ((curr_mode & core#VBDOPT_MASK) | mode)
    if (mode == curr_mode)                      ' no change to shadow reg;
        return                                  ' don't bother writing
    else
        _brd_wvf_ctrl := mode
    writereg(core#BRD_WV_CTRL, 1, @_brd_wvf_ctrl)

PUB border_vbd_lev(level): curr_lev
' Set border fixed VBD level
'   Valid values:
'       BRD_VSS (%00)
'       BRD_VSH1 (%01)
'       BRD_VSL (%10)
'       BRD_VSH2 (%11)
'   Any other value returns the current (cached) setting
    curr_lev := _brd_wvf_ctrl
    case level
        BRD_VSS, BRD_VSH1, BRD_VSL, BRD_VSH2:
            level <<= core#VBDLVL
        other:
            return ((curr_lev >> core#VBDLVL) & core#VBDLVL_BITS)

    level := ((curr_lev & core#VBDLVL_MASK) | level)
    if (level == curr_lev)                      ' no change to shadow reg;
        return                                  ' don't bother writing
    else
        _brd_wvf_ctrl := level
    writereg(core#BRD_WV_CTRL, 1, @_brd_wvf_ctrl)

#ifndef GFX_DIRECT
PUB clear{}
' Clear the display buffer
    bytefill(_ptr_drawbuffer, _bgcolor, _buff_sz)
#endif

PUB dig_blk_ctrl{} | tmp
' Digital Block control
    tmp := $3b
    writereg(core#DIGI_BLK_CTRL, 1, @tmp)

PUB draw_area(sx, sy, ex, ey) | tmpx, tmpy
' Set drawable display region for subsequent drawing operations
'   Valid values:
'       sx, ex: 0..159
'       sy, ey: 0..295
    tmpx.byte[0] := sx / 8
    tmpx.byte[1] := ex / 8

    tmpy.byte[0] := sy.byte[0]
    tmpy.byte[1] := sy.byte[1]
    tmpy.byte[2] := ey.byte[0]
    tmpy.byte[3] := ey.byte[1]

    writereg(core#RAM_X_WIND, 2, @tmpx)
    writereg(core#RAM_Y_WIND, 4, @tmpy)

PUB disp_lines(lines): curr_lines
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

PUB disp_pos(x, y) | tmp
' Set position for subsequent drawing operations
'   Valid values:
'       x: 0..159
'       y: 0..295
    writereg(core#RAM_X, 1, @x)
    writereg(core#RAM_Y, 2, @y)

PUB disp_rdy{}: flag
' Flag indicating display is ready to accept commands
'   Returns: TRUE (-1) if display is ready, FALSE (0) otherwise
    return (ina[_BUSY] == 0)

PUB disp_upd_ctrl2{} | tmp

    tmp := $c7
    writereg(core#DISP_UP_CTRL2, 1, 0)

PUB dummy_line_per(ln_per)

    writereg(core#DUMMY_LN_PER, 1, @ln_per)

PUB gate_first_chan(ch): curr_ch
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

PUB gate_high_voltage(lvl): curr_lvl
' Set gate driving voltage (VGH), in millivolts
'   Valid values: 10_000..21_000 (rounded to increments of 500mV)
'   Any other value returns the current (cached) setting
    curr_lvl := _gate_drv_volt
    case lvl
        10_000..21_000:
            lvl := (((lvl-10_000) / 500) + $03) ' $03 == 10_000
        other:
            return ((10_000 + (curr_lvl - $03)) * 500)

    if (lvl == curr_lvl)                        ' no change to shadow reg;
        return                                  '   don't bother writing
    else
        _gate_drv_volt := lvl
        writereg(core.GATE_DRV_CTRL, 1, @_gate_drv_volt)

PUB gate_line_width(ln_wid)

    writereg(core#GATE_LN_WID, 1, @ln_wid)

PUB gate_start_pos(row)

    writereg(core#GATE_ST_POS, 2, @row)

PUB interlace_ena(state): curr_state
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

PUB master_act{}

    command(core#MASTER_ACT)

PUB mirror_v(state): curr_state  'XXX not functional yet
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

PUB plot(x, y, color)
' Plot pixel at (x, y) in color
    if (x < 0 or x > _disp_xmax) or (y < 0 or y > _disp_ymax)
        return                                  ' coords out of bounds, ignore
#ifdef GFX_DIRECT
' direct to display
'   (not implemented)
#else
' buffered display
    case color
        1:
            byte[_ptr_drawbuffer][(x + y * _disp_width) >> 3] |= $80 >> (x & 7)
        0:
            byte[_ptr_drawbuffer][(x + y * _disp_width) >> 3] &= !($80 >> (x & 7))
        -1:
            byte[_ptr_drawbuffer][(x + y * _disp_width) >> 3] ^= $80 >> (x & 7)
        other:
            return
#endif

#ifndef GFX_DIRECT
PUB point(x, y): pix_clr
' Get color of pixel at x, y
    x := 0 #> x <# _disp_xmax
    y := 0 #> y <# _disp_ymax

    return byte[_ptr_drawbuffer][(x + y * _disp_width) >> 3]
#endif

PUB reset{}
' Reset the device
    if (lookdown(_RST: 0..31))                  ' only touch the reset pin
        outa[_RST] := 1                         ' if it's defined
        dira[_RST] := 1
        outa[_RST] := 0
        time.msleep(200)
        outa[_RST] := 1
        time.msleep(200)
    else                                        ' otherwise, just perform
        command(core#SWRESET)                   '   soft-reset
        time.usleep(core#T_POR)
    repeat until disp_rdy{}

PUB show{}
' Send the draw buffer to the display
    writereg(core#WR_RAM_BW, _buff_sz, _ptr_drawbuffer)
    disp_upd_ctrl2{}
    master_act{}
    command(core#NOOP)

    repeat until disp_rdy{}

PUB vcom_voltage(volts) | tmp
' Set VCOM voltage level, in millivolts
    case volts
        -3_000..-0_200:
            volts := volts / 25
        other:
            return
    writereg(core#WR_VCOM, 1, @volts)

PUB vsh1_voltage(lvl): curr_lvl
' Set source driving voltage (VSH1), in millivolts
'   Valid values: 2_400..18_000
'       2_400..8_800: rounded to multiples of 100mV
'       9_000..18_000: rounded to multiples of 200mV
'   Any other value returns the current (cached) setting
    curr_lvl := _src_drv_volt[VSH1]
    case lvl
        2_400..8_800:
            lvl := ((lvl - 2_400) / 100) + $8E  ' $8E == 2_400 (+.1, .2, .3...)
        9_000..18_000:
            lvl := ((lvl - 9_000) / 200) + $23  ' $23 == 9_000 (+.2, .4, .6...)
        other:
            case curr_lvl
                $8E..$CE:                       ' 2_400..8_800
                    return (((curr_lvl - $8E) * 100) + 2_400)
                $23..$50:                       ' 9_000..18_000
                    return (((curr_lvl - $23) * 200) + 9_000)

    if (lvl == curr_lvl)                        ' no change to shadow reg;
        return                                  '   don't bother writing
    else
        _src_drv_volt[VSH1] := lvl
        writereg(core#SRC_DRV_CTRL, 3, @_src_drv_volt)

PUB vsh2_voltage(lvl): curr_lvl
' Set source driving voltage (VSH2), in millivolts
'   Valid values: 2_400..18_000
'       2_400..8_800: rounded to multiples of 100mV
'       9_000..18_000: rounded to multiples of 200mV
'   Any other value returns the current (cached) setting
    curr_lvl := _src_drv_volt[VSH2]
    case lvl
        2_400..8_800:
            lvl := ((lvl - 2_400) / 100) + $8E  ' $8E == 2_400 (+.1, .2, .3...)
        9_000..18_000:
            lvl := ((lvl - 9_000) / 200) + $23  ' $23 == 9_000 (+.2, .4, .6...)
        other:
            case curr_lvl
                $8E..$CE:                       ' 2_400..8_800
                    return (((curr_lvl - $8E) * 100) + 2_400)
                $23..$50:                       ' 9_000..18_000
                    return (((curr_lvl - $23) * 200) + 9_000)

    if (lvl == curr_lvl)                        ' no change to shadow reg;
        return                                  '   don't bother writing
    else
        _src_drv_volt[VSH2] := lvl
        writereg(core#SRC_DRV_CTRL, 3, @_src_drv_volt)

PUB vsl_voltage(lvl): curr_lvl
' Set source driving voltage (VSL), in millivolts
'   Valid values: -18_000..-9_000 (rounded to multiples of 500mV)
'   Any other value returns the current (cached) setting
    curr_lvl := _src_drv_volt[VSL]
    case lvl
        -18_000..-9_000:
            lvl := ((-lvl - 9_000) / 250) + $1A
        other:
            return -(((curr_lvl - $1A) * 250) + 9_000)

    if (lvl == curr_lvl)                        ' no change to shadow reg;
        return                                  '   don't bother writing
    else
        _src_drv_volt[VSL] := lvl
        writereg(core#SRC_DRV_CTRL, 3, @_src_drv_volt)

PUB wr_lut(ptr_lut)
' Write display waveform lookup table
'   NOTE: The data pointed to must be exactly 70 bytes
    writereg(core#WR_LUT, 70, ptr_lut)

CON

    CMD     = 0
    DATA    = 1

PRI command(c)
' Issue command without parameters to display
    case c
        core#SWRESET, core#MASTER_ACT, core#NOOP:
            outa[_DC] := CMD
            outa[_CS] := 0
            spi.wr_byte(c)
            outa[_CS] := 1

#ifndef GFX_DIRECT
PRI memfill(xs, ys, val, count)
' Fill region of display buffer memory
'   xs, ys: Start of region
'   val: Color
'   count: Number of consecutive memory locations to write
    bytefill(_ptr_drawbuffer + (xs + (ys * _bytesperln)), val, count)
#endif

PRI writereg(reg_nr, nr_bytes, ptr_buff)
' Write nr_bytes to the device from ptr_buff
    case reg_nr
        core#WR_RAM_BW:
            outa[_DC] := CMD
            outa[_CS] := 0
            spi.wr_byte(reg_nr)
            outa[_DC] := DATA
            spi.wrblock_lsbf(ptr_buff, nr_bytes)
            outa[_CS] := 1
            return
        $01, $03, $04, $0C, $0F, $10, $11, $14, $15, $1A, $1C, ...
        $26, $28, $29, $2C, $31, $32, $3A..$3C, $41, $44..$47, $4E, $4F, $74, ...
        $7E, $7F:
            outa[_DC] := CMD
            outa[_CS] := 0
            spi.wr_byte(reg_nr)

            outa[_DC] := DATA
            spi.wrblock_lsbf(ptr_buff, nr_bytes)
            outa[_CS] := 1
        other:
            return

DAT

' LUT waveform data
    _lut_2p13_bw_full
    '35
    byte    {0} $80, $60, $40, $00, $00, $00, $00   ' LUT0: BB:     VS 0 ~7
    byte    {7} $10, $60, $20, $00, $00, $00, $00   ' LUT1: BW:     VS 0 ~7
    byte    {14}$80, $60, $40, $00, $00, $00, $00   ' LUT2: WB:     VS 0 ~7
    byte    {21}$10, $60, $20, $00, $00, $00, $00   ' LUT3: WW:     VS 0 ~7
    byte    {28}$00, $00, $00, $00, $00, $00, $00   ' LUT4: VCOM:   VS 0 ~7

    '35
    byte    {35}$03, $03, $00, $00, $02             ' TP0 A~D RP0
    byte    {40}$09, $09, $00, $00, $02             ' TP1 A~D RP1
    byte    {45}$03, $03, $00, $00, $02             ' TP2 A~D RP2
    byte    {50}$00, $00, $00, $00, $00             ' TP3 A~D RP3
    byte    {55}$00, $00, $00, $00, $00             ' TP4 A~D RP4
    byte    {60}$00, $00, $00, $00, $00             ' TP5 A~D RP5
    byte    {65}$00, $00, $00, $00, $00             ' TP6 A~D RP6

    '6
    byte    {70}$15, $41, $A8, $32, $30, $0A        ' GDC, SDC[0..2], DL, GT

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

