# il3897-spin 
-------------

This is a P8X32A/Propeller, P2X8C4M64P/Propeller 2 driver object for IL3897 E-Ink displays.

**IMPORTANT**: This software is meant to be used with the [spin-standard-library](https://github.com/avsa242/spin-standard-library) (P8X32A) or [p2-spin-standard-library](https://github.com/avsa242/p2-spin-standard-library) (P2X8C4M64P). Please install the applicable library first before attempting to use this code, otherwise you will be missing several files required to build the project.

## Salient Features

* SPI connection at 20MHz (P1), up to 15MHz (P2)

## Requirements
OA
P1/SPIN1:
* spin-standard-library
* 1 additional core/cog for the PASM SPI engine

P2/SPIN2:
* p2-spin-standard-library

## Compiler Compatibility

* P1/SPIN1: OpenSpin (tested with 1.00.81)
* P2/SPIN2: FlexSpin (tested with 5.3.2)
* ~~BST~~ (incompatible - no preprocessor)
* ~~Propeller Tool~~ (incompatible - no preprocessor)
* ~~PNut~~ (incompatible - no preprocessor)

## Hardware Compatibility

* Tested with 2.13" BW panel (HINK-E0213A22), [Parallax #64204](https://www.parallax.com/product/eink-click-e-paper-bundle-2/)

## Known issues

* SPIN2/P2 driver doesn't display with SPI clock >15MHz

## Limitations

* Very early in development - may malfunction, or outright fail to build

## TODO

- [ ] TBD
