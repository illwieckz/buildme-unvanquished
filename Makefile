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

ifeq ($(VM_TYPE),)
VM_TYPE := 3
endif

BIN_ARGS := -set vm.cgame.type ${VM_TYPE} -set vm.sgame.type ${VM_TYPE}

EXTRA_PAKPATHS := $(shell sh -c "[ -f .pakpaths ] && sed -e 's/^/-pakpath \"/;s/$$/\"/' .pakpaths | tr '\n' ' '")

clone-engine:
	(! [ -d "${ENGINE_DIR}" ] && git clone "${ENGINE_REPO}" "${ENGINE_DIR}") || true

clone-vm:
	(! [ -d "${GAMEVM_DIR}" ] && git clone "${GAMEVM_REPO}" "${GAMEVM_DIR}") || true

clone-assets:
	(! [ -d "${ASSETS_DIR}" ] && git clone "${ASSETS_REPO}" "${ASSETS_DIR}") || true
	make -C "${ASSETS_DIR}" clone

clone-bin: clone-engine clone-vm

clone: clone-bin clone-assets

pull-engine:
	cd "${ENGINE_DIR}" && (git remote | grep '^upstream$$' || git remote add upstream "${ENGINE_REPO}") || true
	cd "${ENGINE_DIR}" && git checkout master && git pull upstream master

pull-vm:
	cd "${GAMEVM_DIR}" && (git remote | grep '^upstream$$' || git remote add upstream "${GAMEVM_REPO}") || true
	cd "${GAMEVM_DIR}" && git checkout master && git pull upstream master

pull-assets:
	cd "${ASSETS_DIR}" && (git remote | grep '^upstream$$' || git remote add upstream "${ASSETS_REPO}") || true
	cd "${ASSETS_DIR}" && git checkout master && git pull upstream master
	make -C "${ASSETS_DIR}" pull

pull-bin: pull-engine pull-vm

pull: pull-bin pull-assets

engine:
	cmake "${ENGINE_DIR}" -B"${ENGINE_BUILD}" -G"Unix Makefiles"
	cmake --build "${ENGINE_BUILD}" -- -j${NPROC}

vm:
	# workaround: some git stuff is trying to compute version number using on git refs,
	# it makes cmake complaining when building game code out of source tree,
	# so let's change directory before building

	cd "${GAMEVM_DIR}" ; cmake "${GAMEVM_DIR}" -B"${GAMEVM_BUILD}" -G"Unix Makefiles" \
		-DBUILD_SERVER=0 -DBUILD_CLIENT=0 -DBUILD_TTY_CLIENT=0 \
		-DBUILD_GAME_NACL=0 -DBUILD_GAME_NACL_NEXE=0 \
		-DDAEMON_DIR="${ENGINE_DIR}"
	cmake --build "${GAMEVM_BUILD}" -- -j${NPROC}

assets:
	make -C "${ASSETS_DIR}" build

bin: engine vm

data: assets

build: bin data

run-server:
	"${ENGINE_BUILD}/daemonded" \
		${BIN_ARGS} \
		-libpath "${GAMEVM_BUILD}" \
		-pakpath "${ASSETS_BUILD}" \
		${EXTRA_PAKPATHS} \
		${EXTRA_ARGS} \
		+set language en \
		+set developer 1 \
		+set logs.logLevel.common.commands debug \
		+set logs.logLevel.common.cm debug \
		+set logs.logLevel.fs verbose \

run-client:
	"${ENGINE_BUILD}/daemon" \
		${BIN_ARGS} \
		-libpath "${GAMEVM_BUILD}" \
		-pakpath "${ASSETS_BUILD}" \
		${EXTRA_PAKPATHS} \
		${EXTRA_ARGS} \
		+set language en \
		+set developer 1 \
		+set logs.logLevel.common.commands debug \
		+set logs.logLevel.common.cm debug \
		+set logs.logLevel.fs verbose \

run-tty:
	"${ENGINE_BUILD}/daemon-tty" \
		${BIN_ARGS} \
		-libpath "${GAMEVM_BUILD}" \
		-pakpath "${ASSETS_BUILD}" \
		${EXTRA_PAKPATHS} \
		${EXTRA_ARGS} \
		+set language en \
		+set developer 1 \
		+set logs.logLevel.common.commands debug \
		+set logs.logLevel.common.cm debug \
		+set logs.logLevel.fs verbose \

run: run-client
