Build me Unvanquished!
======================

Simple `Makefile` to build and test [Unvanquished](http://unvanquished.net/) from source.


How-to
------

```sh
# get this repository
git clone https://github.com/illwieckz/buildme-unvanquished.git

# enter the directory
cd buildme-unvanquished

# fetches all sources
make clone

# build data
make data

# build binaries
make bin

# build and run the game
make run

# build and run the game on gdb
make run BUILD='Debug'

# you can also build assets and binaries, run the game,
# load a map and spawn some bots just like that:
make it
```


Advanced usage
--------------

```sh
# Build default build with GCC (assumes gcc and g++)
# with RelWithDebInfo CMake profile,
# Native Client virtual machines, LTO enabled,
# then run the game from folders:
# build/engine/default-gcc-lto-debrel-exe/
# build/game/default-nacl-nolto-debrel-nexe/
make run

# Build with Clang compiler (assumes clang and clang++),
# then run the game,
make run COMPILER='clang'

# Force explicit clang 12 binaries and lld-12 linker,
# and run the game from folders:
# build/engine/default-clang12-lto-reldeb-exe/
# build/game/default-nacl-nolto-reldeb-nexe/
make run COMPILER='clang12' CC_BIN='clang-12' CXX_BIN='clang++-12' LD_BIN='lld-12'

# Build default-like build but with -O3 optimization level,
# then run the game from folders:
# build/engine/o3-gcc-lto-reldeb-exe/
# build/game/o3-nacl-nolto-reldeb-nexe/
make run FLAGS='-O3' PREFIX='o3'

# Do the same but load the plat23 map,
# and move the view position to the alien base entry
make run FLAGS='-O3' PREFIX='o3' \
	ARGS='+devmap plat23 +delay 100f setviewpos 1893 1920 0 0 0'

# Build with Release CMake profile,
# separate executable virtual machines,
# then run the game from folders:
# build/engine/default-gcc-lto-release-exe/
# build/game/default-gcc-lto-release-exe/
make run BUILD='Release' VM='exe'

# Build with Debug CMake profile,
# shared library virtual machines, LTO disabled,
# then run the game on gdb from folders:
# build/engine/default-gcc-nolto-debug-exe/
# build/game/default-gcc-nolto-debug-dll/
make run BUILD='Debug' LTO='OFF' VM='dll'

# Does the same but use nemiver as a debugger
make run BUILD='Debug' LTO='OFF' VM='dll' DEBUG='nemiver'
```

Some options

- `PREFIX`, custom string used in build folder names: defaults to `default`;
- `BUILD`, build profiles: `RelWithDebInfo` (default), `Release`, `Debug`;
- `VM`, virtual machine kind: `nexe` (default), `exe`, `dll`;
- `LTO`, link time optimization: `ON` (default), `OFF`;
- `CC_BIN`, alternate C compiler;
- `CXX_BIN`, alternate C++ compiler;
- `LD_BIN`, alternate linker to use with ld-fuse mechanism;
- `CMAKE_BIN`, alternate cmake binary;
- `CMAKE`, optional extra CMake options;
- `FLAGS`, optional `CFLAGS` and `CXXFLAGS`;
- `DEBUG`, optional debug tool: unset by default, `gdb` or custom commands;
- `PKG`, load assets from dpk archives: `ON`, `OFF` (default).

The `COMPILER` string can be used to switch between default `gcc` or `clang`, or just feed the related field in build directory name when using other compilers with `CC_BIN` and `CXX_BIN`.

Note: some system may call their clang binary `gcc`, then the default `gcc` build would be a clang build. On those system, use `CC_BIN` and `CXX_BIN` variable and set absolute paths to `gcc` and `g++`.


Author
------

Thomas “illwieckz” Debesse


License
-------

This Makefile is covered by the BSD 3-Clause license, see [`LICENSE.md`](LICENSE.md).
