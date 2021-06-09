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

Author
------

Thomas “illwieckz” Debesse

License
-------

This Makefile is covered by the BSD 3-Clause license, see [`LICENSE.md`](LICENSE.md).
