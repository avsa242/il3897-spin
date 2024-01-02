# il3897-spin 
-------------

This is a P8X32A/Propeller, P2X8C4M64P/Propeller 2 driver object for IL3897 E-Ink displays.

**IMPORTANT**: This software is meant to be used with the [spin-standard-library](https://github.com/avsa242/spin-standard-library) (P8X32A) or [p2-spin-standard-library](https://github.com/avsa242/p2-spin-standard-library) (P2X8C4M64P). Please install the applicable library first before attempting to use this code, otherwise you will be missing several files required to build the project.

## Salient Features

* P1: SPI connection at ~28kHz (bytecode SPI engine), 20MHz (PASM-based engine)
* P2: SPI connection at up to 20MHz

## Requirements

P1/SPIN1:
* spin-standard-library
* 1 additional core/cog for the PASM SPI engine (none if bytecode engine is used)
* graphics.common.spinh (provided by spin-standard-library)

P2/SPIN2:
* p2-spin-standard-library
* 250MHz sys clock, for 20MHz SPI bus speed (limit at 160MHz default is 15MHz
* graphics.common.spin2h (provided by spin-standard-library)

## Compiler Compatibility

| Processor | Language | Compiler               | Backend      | Status                |
|-----------|----------|------------------------|--------------|-----------------------|
| P1        | SPIN1    | FlexSpin (6.8.0)       | Bytecode     | OK                    |
| P1        | SPIN1    | FlexSpin (6.8.0)       | Native/PASM  | OK                    |
| P2        | SPIN2    | FlexSpin (6.8.0)       | NuCode       | OK (Untested)         |
| P2        | SPIN2    | FlexSpin (6.8.0)       | Native/PASM2 | OK                    |

(other versions or toolchains not listed are __not supported__, and _may or may not_ work)


## Hardware Compatibility

* Tested with 2.13" BW panel (HINK-E0213A22), [Parallax #64204](https://www.parallax.com/product/eink-click-e-paper-bundle-2/)

## Limitations

* Tri-color panels (e.g., with additional red channel) aren't supported
* Horizontal mirroring not supported
* Rotation not supported

