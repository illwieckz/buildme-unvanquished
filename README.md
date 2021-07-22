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

# build assets
make data

# build binaries
make bin

# build and run the game
make run

# build and run the game on gdb
make run BUILD=debug

# you can also build assets and binaries, run the game,
# load a map and spawn some bots just like that:
make it

```


Advanced usage
--------------

```sh
# Build default build with GCC (assumes /usr/bin/gcc)
# with DebWithRelInfo CMake profile,
# Native Client virtual machines, LTO enabled,
# then run the game from folders:
# build/engine/default-gcc-lto-debrel-exe/
# build/vms/default-nacl-nolto-debrel-nexe/
make run

# Build with Clang compiler (assumes /usr/bin/clang),
# then run the game,
make run COMPILER=clang

# Force explicit clang 12 binaries and lld-12 linker,
# and run the game from folders:
# build/engine/default-clang12-lto-debrel-exe/
# build/vms/default-nacl-nolto-debrel-nexe/
make run COMPILER=clang12 CC=clang-12 CXX=clang++-12 FUSELD=lld-12

# Build default-like build but with -O3 optimization level,
# then run the game from folders:
# build/engine/o3-gcc-lto-debrel-exe/
# build/vms/o3-nacl-nolto-debrel-nexe/
make run FLAGS='-O3' PREFIX=o3

# Does the same but load the plat23 map,
# and move the view position to the alien base entry
make run FLAGS="-O3" PREFIX=o3 \
	ARGS="+devmap plat23 +delay 100f setviewpos 1893 1920 0 0 0"

# Build with Release CMake profile,
# separate executable virtual machines,
# then run the game from folders:
# build/engine/default-gcc-lto-release-exe/
# build/vms/default-gcc-lto-release-exe/
make run BUILD=release VM=exe

# Build with Debug CMake profile,
# shared library virtual machines, LTO disabled,
# then run the game on gdb from folders:
# build/engine/default-gcc-nolto-debug-exe/
# build/vms/default-gcc-nolto-debug-dll/
make run BUILD=debug LTO=OFF VM=dll

# Does the same but use nemiver as a debugger
make run BUILD=debug LTO=OFF VM=dll DEBUG=nemiver
```

Some options

- `PREFIX`, a custom string used in build folder names: defaults to `default`;
- `BUILD`, build profiles: `reldeb` (default), `release`, `debug`;
- `VM`, virtual machine kind: `nexe` (default), `exe`, `dll`;
- `LTO`, link time optimization: `ON` (default), `OFF`;
- `CC`, alternate C compiler, unset by default;
- `CXX`, alternate C++ compiler, unset by default;
- `LDFUSE`, alternate linker to use with ld-fuse mechanism, unset by default;
- `CMAKE`, optional extra CMake options: unset by default;
- `FLAGS`, optional `CFLAGS` and `CXXFLAGS`: unset by default;
- `DEBUG`, optional debug tool: unset by default, `gcc` or custom commands;
- `PKG`, load assets from dpk archives: `ON`, `OFF` (default).


Author
------

Thomas “illwieckz” Debesse


License
-------

This Makefile is covered by the BSD 3-Clause license, see [`LICENSE.md`](LICENSE.md).