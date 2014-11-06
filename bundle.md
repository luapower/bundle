---
project: bundle
tagline: LuaJIT single-executable deployment
---

## WORK IN PROGRESS

## Features

  * can embed:
    * Lua modules, available to require()
	 * Lua/C modules, available to require()
	 * C modules, available to ffi.C
    * arbitrary binary blobs, optionall gzipped, available to bundle.load()
  * portable: works on Windows, Linux, OSX.
  * produces upgradable apps: whenever present, external modules and files
  are loaded instead their embedded counterparts.

## Usage


	./bundle.sh [options...]


## Executable compression pros/cons

Compressing large executables is not recommended because compressed
executables cannot be mmapped, so they have to stay in RAM fully.

If the exe contains a lot of big blobs, better results can be acheived
by compressing the blobs themselves and loading and decompressing them
on-demand.
