# il3897-spin 
-------------

This is a P8X32A/Propeller, P2X8C4M64P/Propeller 2 driver object for IL3897 E-Ink displays.

**IMPORTANT**: This software is meant to be used with the [spin-standard-library](https://github.com/avsa242/spin-standard-library) (P8X32A) or [p2-spin-standard-library](https://github.com/avsa242/p2-spin-standard-library) (P2X8C4M64P). Please install the applicable library first before attempting to use this code, otherwise you will be missing several files required to build the project.

## Salient Features

* SPI connection at 20MHz (P1), up to 20MHz (P2)

## Requirements
OA
P1/SPIN1:
* spin-standard-library
* 1 additional core/cog for the PASM SPI engine

P2/SPIN2:
* p2-spin-standard-library
* 250MHz sys clock, for 20MHz SPI bus speed (limit at 160MHz default is 15MHz

## Compiler Compatibility

* P1/SPIN1 OpenSpin (bytecode): OK, tested with 1.00.81
* P1/SPIN1 FlexSpin (bytecode): OK, tested with 5.9.7-beta
* P1/SPIN1 FlexSpin (native): OK, tested with 5.9.7-beta
* ~~P2/SPIN2 FlexSpin (nu-code): FTBFS, tested with 5.9.7-beta~~
* P2/SPIN2 FlexSpin (native): OK, tested with 5.9.7-beta
* ~~BST~~ (incompatible - no preprocessor)
* ~~Propeller Tool~~ (incompatible - no preprocessor)
* ~~PNut~~ (incompatible - no preprocessor)

## Hardware Compatibility

* Tested with 2.13" BW panel (HINK-E0213A22), [Parallax #64204](https://www.parallax.com/product/eink-click-e-paper-bundle-2/)

## Limitations

* Very early in development - may malfunction, or outright fail to build
* Tri-color panels (e.g., with additional red channel) aren't supported

