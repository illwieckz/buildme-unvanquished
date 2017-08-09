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

# build binaries (engine, vm)
make bin -j$(nproc)

# run the game
make run
```

Author
------

Thomas “illwieckz” Debesse

License
-------

This Makefile is covered by BSD 3-Clause license, see [`LICENSE.md`](LICENSE.md).
