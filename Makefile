# Copyright © 2017, Thomas Debesse
# Covered by BSD 3-Clause license
# See LICENSE.md for details

.DEFAULT_GOAL := build

ROOT_DIR := $(shell dirname $(realpath $(lastword $(MAKEFILE_LIST))))
NPROC := $(shell nproc)

ENGINE_REPO := https://github.com/DaemonEngine/Daemon.git
GAMEVM_REPO := https://github.com/Unvanquished/Unvanquished.git
ASSETS_REPO := https://github.com/UnvanquishedAssets/UnvanquishedAssets.git

ENGINE_DIR := ${ROOT_DIR}/Daemon
GAMEVM_DIR := ${ROOT_DIR}/Unvanquished
ASSETS_DIR := ${ROOT_DIR}/UnvanquishedAssets

ENGINE_BUILD := ${ENGINE_DIR}/build
GAMEVM_BUILD := ${GAMEVM_DIR}/build
ASSETS_BUILD := ${ASSETS_DIR}/build/test

clone-engine:
	! [ -d ${ENGINE_DIR} ] && git clone ${ENGINE_REPO} ${ENGINE_DIR}

clone-gamevm:
	! [ -d ${GAMEVM_DIR} ] && git clone ${GAMEVM_REPO} ${GAMEVM_DIR}

clone-assets:
	! [ -d ${ASSETS_DIR} ] && git clone ${ASSETS_REPO} ${ASSETS_DIR}
	make -C ${ASSETS_DIR} clone

clone-bin: clone-engine clone-gamevm

clone: clone-bin clone-assets

build-engine:
	cmake -H${ENGINE_DIR} -B${ENGINE_BUILD} -G"Unix Makefiles"
	cmake --build ${ENGINE_BUILD} -- -j${NPROC}

build-gamevm:
	# workaround: some git stuff computing version number based on git refs
	# makes cmake complaining when building game code out of source tree,
	# so let's change directory before building

	cd ${GAMEVM_DIR} ; cmake -H${GAMEVM_DIR} -B${GAMEVM_BUILD} -G"Unix Makefiles" \
		-DBUILD_SERVER=0 -DBUILD_CLIENT=0 -DBUILD_TTY_CLIENT=0 \
		-DBUILD_GAME_NACL=0 -DBUILD_GAME_NACL_NEXE=0 \
		-DDAEMON_DIR=${ENGINE_DIR}
	cmake --build ${GAMEVM_BUILD} -- -j${NPROC}

build-assets:
	make -C ${ASSETS_DIR} build

build-bin: build-engine build-gamevm

build-data: build-assets

build: build-bin build-data

run:
	${ENGINE_BUILD}/daemon \
		-set vm.cgame.type 3 -set vm.sgame.type 3 \
		-libpath ${GAMEVM_BUILD} \
		-pakpath ${ASSETS_BUILD} \
		+set language en \
		+set developer 1 \
		+set logs.logLevel.common.commands debug \
		+set logs.logLevel.common.cm debug \
		+set logs.logLevel.fs verbose \
		+nocurses
