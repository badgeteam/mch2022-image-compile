# MCH2022 badge FatFS compilation and flash script generation

This repository is basically an aggregator of other projects for the MCH badge. Its purpose is to build the firmware and images for other partitions, generate a FatFS partition for the internal FAT partition and make them all flashable in one command. 

This repo includes the firmware repository as a submodule, which in turn contains the ESP IDF in the version required for the firmware to compile (currently release version 4.4.1). It includes another instance of the ESP IDF in a diffent version (current master) for building the wear-leveled FatFS image. At time of writing, these versions differ. At a later time, this process might be simplified. Note that currently only the firmware version of the IDF will be sourced and used. The IDF master is only used for referencing the FATFS generation scripts.

The whole process is done in the Makefile. It will:

- compile the firmware (including bootloader, partition table, and other partition binaries)
- compile the sponsor slideshow app (that is also included as a submodule)
- generate an appfs image and add the slideshow app to it
- generate a wear-balanced fatfs filesystem
- copy all needed binaries to a destination directory
- generate an args file that can be passed to esptool.py

# Needed

- git
- GNU make

(other stuff such as python will be installed by and used from the firmware submodule)

# How to use

- Clone this repo
- initialize submodules: ```git submodule update --init --recursive```
- Copy files that should go into the FatFS partition into the ```fatfs-contents``` directory, remove the placeholder file.
- run ```make```
- The esptool.py arguments to use will be printed when make is done.

# Single bin operation

The default procedure will collect several binary blobs and generate a script to flash them all individually. Alternatively, you can run ```make singlebin```, which will merge all binary blobs into a single image file to flash to address 0x0. This may be slightly slower to flash, but a single file may be convenient in certain situations.

# Performance

The ESP32 WROVER module can use flash mode qio for fastest memory access. However, this does not seem to be a bottleneck. Choosing a good Serial speed is the most important factor. During testing here, a speed of around 2Mbit/s was the fastest option without running into communication errors. 

## Approximate times

- Flash individual bins without -e (full erase) option: 80s
- Flash individual bins with -e (full erase) option: 85s
- Flash single bin (implies full erase): 85s





