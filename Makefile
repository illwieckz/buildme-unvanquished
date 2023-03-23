# Copyright © 2017, Thomas Debesse
# Covered by BSD 3-Clause license
# See LICENSE.md for details

.DEFAULT_GOAL := build
.PHONY: data bin bin-client bin-server bin-tty build build-data build-maps build-resources clean-bin clean-engine clean-game clone clone-data clone-bin clone-engine clone-game configure-engine configure-game data engine engine-client engine-server engine-tty it maps package-data package-maps package-resources prepare-data prepare-maps prepare-resources pull pull-data pull-bin pull-engine pull-game resources run run-client run-server run-tty set-current-engine set-current-game game

ROOT_DIR := $(shell dirname $(realpath $(lastword $(MAKEFILE_LIST))))
NPROC := $(shell nproc)

ENGINE_REPO := https://github.com/DaemonEngine/Daemon.git
GAME_REPO := https://github.com/Unvanquished/Unvanquished.git
DATA_REPO := https://github.com/UnvanquishedAssets/UnvanquishedAssets.git

ENGINE_DIR := ${ROOT_DIR}/Daemon
GAME_DIR := ${ROOT_DIR}/Unvanquished
DATA_DIR := ${ROOT_DIR}/UnvanquishedAssets

BUILD_DIR := ${ROOT_DIR}/build
EXDEPS_DIR := ${BUILD_DIR}/deps

CLIENT_ARGS := -set client.allowRemotePakDir on
SERVER_ARGS := -set sv_pure 0

SYSTEM := $(shell uname -s)

LN_BIN := ln
ifeq ($(SYSTEM),Darwin)
	LN_BIN := gln
endif

ifeq ($(CMAKE_BIN),)
	CMAKE_BIN := cmake
endif

ifeq ($(PREFIX),)
	PREFIX := default
endif

ifeq ($(DPK),)
	DPK := OFF
endif

ifeq ($(DPK),ON)
	PAK_PREFIX := pkg
	DATA_ACTION := package
else ifeq ($(DPK),OFF)
	PAK_PREFIX := test
	DATA_ACTION := build
endif

ifeq ($(VM),)
	VM := nexe
endif

ifeq ($(VM),nexe)
else ifeq ($(VM),exe)
else ifeq ($(VM),dll)
else
$(error Bad VM value: $(VM))
endif

ifeq ($(VM),nexe)
	ifeq ($(NEXE),)
		NEXE := native
	endif
endif

ifeq ($(BUILD),)
	BUILD := RelWithDebInfo
endif

ifeq ($(BUILD),Debug)
else ifeq ($(BUILD),RelWithDebInfo)
else ifeq ($(BUILD),Release)
else
$(error Bad BUILD value: $(VM))
endif

ifeq ($(LTO),OFF)
else ifeq ($(LTO),ON)
else ifeq ($(LTO),)
	LTO := ON
else
$(error Bad LTO value: $(VM))
endif

ifneq ($(FUSELD),)
	CMAKE_FUSELD_ARGS := -D'CMAKE_EXE_LINKER_FLAGS_INIT'='-fuse-ld=${FUSELD}' -D'CMAKE_MODULE_LINKER_FLAGS_INIT'='-fuse-ld=${FUSELD}' -D'CMAKE_SHARED_LINKER_FLAGS_INIT'='-fuse-ld=${FUSELD}'
else
	CMAKE_FUSELD_ARGS :=
endif

ifeq ($(COMPILER),)
	COMPILER_SLUG := $(shell gcc --version 2>/dev/null | if grep -q clang; then echo clang; else echo gcc; fi)
else ifeq ($(COMPILER),gcc)
	COMPILER_SLUG := gcc
	CC_BIN := gcc
	CXX_BIN := g++
else ifeq ($(COMPILER),clang)
	COMPILER_SLUG := clang
	CC_BIN := clang
	CXX_BIN := clang++
endif

# CC and CXX are always set by Make, so we cannot rely on those variable names.
ifneq ($(CC_BIN),)
	CMAKE_C_COMPILER_ARGS := -D'CMAKE_C_COMPILER'='$(CC_BIN)'
else
	CMAKE_C_COMPILER_ARGS :=
endif

ifneq ($(CXX_BIN),)
	CMAKE_CXX_COMPILER_ARGS := -D'CMAKE_CXX_COMPILER'='$(CXX_BIN)'
else
	CMAKE_CXX_COMPILER_ARGS :=
endif

CMAKE_COMPILER_ARGS := ${CMAKE_C_COMPILER_ARGS} ${CMAKE_CXX_COMPILER_ARGS}

ifneq ($(FLAGS),)
	CMAKE_COMPILER_FLAGS := -D'CMAKE_C_FLAGS'='${FLAGS}' -D'CMAKE_CXX_FLAGS'='${FLAGS}'
else
	CMAKE_COMPILER_FLAGS :=
endif

ifeq ($(BUILD),Release)
	BUILD_SLUG := release
	CMAKE_DEBUG_ARGS := -D'USE_BREAKPAD'='OFF' -D'CMAKE_BUILD_TYPE'='Release' -D'USE_DEBUG_OPTIMIZE'='OFF'
else ifeq ($(BUILD),Debug)
	BUILD_SLUG := debug
	CMAKE_DEBUG_ARGS := -D'USE_BREAKPAD'='OFF' -D'CMAKE_BUILD_TYPE'='Debug' -D'USE_DEBUG_OPTIMIZE'='OFF' -D'CMAKE_EXE_LINKER_FLAGS'='-lprofiler -ltcmalloc'

	# Hardcode that .gdbinit.txt path since “auto-load safe-path” usually prevents loading .gdbinit from current dir
	# Use another name to prevent printing useless warnings saying it will not loaded since we force it to be loaded
	DEBUG := gdb -x .gdbinit.txt -args
else ifeq ($(BUILD),RelWithDebInfo)
	BUILD_SLUG := reldeb
	CMAKE_DEBUG_ARGS := -D'USE_BREAKPAD'='OFF' -D'CMAKE_BUILD_TYPE'='RelWithDebInfo' -D'USE_DEBUG_OPTIMIZE'='ON'

	# See above.
	DEBUG := gdb -x .gdbinit.txt -args
else
	DEBUG :=
endif

ifeq ($(VM),dll)
	VM_TYPE := 3
	CMAKE_GAME_ARGS := -D'BUILD_GAME_NACL'='OFF' -D'BUILD_GAME_NACL_NEXE'='OFF' -D'BUILD_GAME_NATIVE_EXE'='OFF' -D'BUILD_GAME_NATIVE_DLL'='ON'
else ifeq ($(VM),exe)
	VM_TYPE := 2
	CMAKE_GAME_ARGS := -D'BUILD_GAME_NACL'='OFF' -D'BUILD_GAME_NACL_NEXE'='OFF' -D'BUILD_GAME_NATIVE_EXE'='ON' -D'BUILD_GAME_NATIVE_DLL'='OFF'
else ifeq ($(VM),nexe)
	VM_TYPE := 1
	CMAKE_GAME_ARGS := -D'BUILD_GAME_NACL'='ON' -D'BUILD_GAME_NACL_NEXE'='ON' -D'BUILD_GAME_NACL_TARGETS'="$(NEXE)" -D'BUILD_GAME_NATIVE_EXE'='OFF' -D'BUILD_GAME_NATIVE_DLL'='OFF'
endif

ifeq ($(LTO),ON)
	LINK := lto
else
	LINK := nolto
endif

ifeq ($(VM),nexe)
	GAME_LINK := nolto
	GAME_LTO := OFF
	GAME_COMPILER_SLUG := nacl
	CMAKE_GAME_COMPILER_ARGS :=
	CMAKE_GAME_FUSELD_ARGS :=
else
	GAME_LINK := ${LINK}
	GAME_LTO := $(LTO)
	GAME_COMPILER_SLUG := ${COMPILER_SLUG}
	CMAKE_GAME_COMPILER_ARGS := $(CMAKE_COMPILER_ARGS)
	CMAKE_GAME_FUSELD_ARGS := $(CMAKE_FUSELD_ARGS)
endif

ENGINE_PREFIX := ${PREFIX}-${COMPILER_SLUG}-${LINK}-${BUILD_SLUG}-exe
GAME_PREFIX := ${PREFIX}-${GAME_COMPILER_SLUG}-${GAME_LINK}-${BUILD_SLUG}-${VM}

ENGINE_BUILD := ${BUILD_DIR}/engine/${ENGINE_PREFIX}
GAME_BUILD := ${BUILD_DIR}/game/${GAME_PREFIX}

DATA_BUILD_PREFIX := ${BUILD_DIR}/assets
DATA_BUILD := ${DATA_BUILD_PREFIX}/${PAK_PREFIX}

ENGINE_VMTYPE_ARGS := -set vm.cgame.type ${VM_TYPE} -set vm.sgame.type ${VM_TYPE}

ifeq ($(LOG),Debug)
	ENGINE_LOG_ARGS := -set logs.suppression.enabled 0 -set logs.level.default debug -set logs.level.audio debug -set logs.level.glconfig debug -set developer 1
else
	ENGINE_LOG_ARGS := -set logs.suppression.enabled 1 -set logs.level.default notice -set logs.level.audio notice  -set logs.level.glconfig notice -set developer 0
endif

ifneq ($(DATA),OFF)
	DPKDIR_PAKPATH_ARGS := -pakpath '${DATA_BUILD}'
else
	DPKDIR_PAKPATH_ARGS :=
endif

EXTRA_PAKPATHS := $(shell [ -f .pakpaths ] && ( grep -v '\#' .pakpaths | sed -e 's/^/-pakpath /' | tr '\n' ' '))

ifneq ($(EXTRA_PAKPATHS),)
	EXTRA_PAKPATH_ARGS := ${EXTRA_PAKPATHS}
else
	EXTRA_PAKPATH_ARGS :=
endif

clone-engine:
	(! [ -d '${ENGINE_DIR}' ] && git clone '${ENGINE_REPO}' '${ENGINE_DIR}') || true

clone-game:
	(! [ -d '${GAME_DIR}' ] && git clone '${GAME_REPO}' '${GAME_DIR}') || true

clone-assets:
	(! [ -d '${DATA_DIR}' ] && git clone '${DATA_REPO}' '${DATA_DIR}') || true
	cd '${DATA_DIR}' && git submodule update --init --recursive

clone-bin: clone-engine clone-game

clone: clone-bin clone-assets

pull-engine:
	cd '${ENGINE_DIR}' && git checkout master && git pull origin master

pull-game:
	cd '${GAME_DIR}' && git checkout master && git pull origin master

pull-assets:
	cd '${DATA_DIR}' && git checkout master && git pull origin master
	cd '${DATA_DIR}' && git submodule foreach pull origin master

pull-bin: pull-engine pull-game

pull: pull-bin pull-assets

configure-engine:
	${CMAKE_BIN} '${ENGINE_DIR}' -B'${ENGINE_BUILD}' \
		${CMAKE_COMPILER_ARGS} \
		${CMAKE_FUSELD_ARGS} \
		${CMAKE_DEBUG_ARGS} \
		${CMAKE_COMPILER_FLAGS} \
		${CMAKE} \
		-D'USE_LTO'='${LTO}' \
		-D'EXTERNAL_DEPS_DIR'='${EXDEPS_DIR}' \
		-D'BUILD_SERVER'='ON' -D'BUILD_CLIENT'='ON' -D'BUILD_TTY_CLIENT'='ON' \
		-G'Unix Makefiles'

set-current-engine:
	${LN_BIN} --verbose --symbolic --force --no-target-directory ${ENGINE_PREFIX} build/engine/current

engine-server: set-current-engine configure-engine
	${CMAKE_BIN} --build '${ENGINE_BUILD}' -- -j'${NPROC}' server

engine-client: set-current-engine configure-engine
	${CMAKE_BIN} --build '${ENGINE_BUILD}' -- -j'${NPROC}' client

engine-tty: set-current-engine configure-engine
	${CMAKE_BIN} --build '${ENGINE_BUILD}' -- -j'${NPROC}' ttyclient

configure-game:
	${CMAKE_BIN} '${GAME_DIR}' -B'${GAME_BUILD}' \
		${CMAKE_GAME_COMPILER_ARGS} \
		${CMAKE_GAME_FUSELD_ARGS} \
		${CMAKE_DEBUG_ARGS} \
		${CMAKE_GAME_ARGS} \
		${CMAKE_COMPILER_FLAGS} \
		${CMAKE} \
		-D'USE_LTO'='${GAME_LTO}' \
		-D'EXTERNAL_DEPS_DIR'='${EXDEPS_DIR}' \
		-D'BUILD_SERVER'='OFF' -D'BUILD_CLIENT'='OFF' -D'BUILD_TTY_CLIENT'='OFF' \
		-D'BUILD_SGAME'='ON' -D'BUILD_CGAME'='ON' \
		-D'DAEMON_DIR'='${ENGINE_DIR}' \
		-G'Unix Makefiles'
	echo "${VM_TYPE}" > "${GAME_BUILD}/vm_type.txt"

set-current-game:
	mkdir -p build/game
	${LN_BIN} --verbose --symbolic --force --no-target-directory ${GAME_PREFIX} build/game/current

game: set-current-game configure-game
	${CMAKE_BIN} --build '${GAME_BUILD}' -- -j'${NPROC}'
	${LN_BIN} --verbose --symbolic --force ${ENGINE_BUILD}/irt_core-x86_64.nexe ${GAME_BUILD}/irt_core-x86_64.nexe
	${LN_BIN} --verbose --symbolic --force ${ENGINE_BUILD}/nacl_helper_bootstrap ${GAME_BUILD}/nacl_helper_bootstrap
	${LN_BIN} --verbose --symbolic --force ${ENGINE_BUILD}/nacl_loader ${GAME_BUILD}/nacl_loader

bin-client: engine-client game

bin-server: engine-server game

bin-tty: engine-tty game

engine: engine-server engine-client engine-tty

bin: engine game

prepare-maps:
	cd '${DATA_DIR}' && urcheon prepare src/map-*.dpkdir

build-maps: prepare-maps
	cd '${DATA_DIR}' && urcheon --build-prefix='${DATA_BUILD_PREFIX}' build src/map-*.dpkdir

package-maps: build-maps
	cd '${DATA_DIR}' && urcheon --build-prefix='${DATA_BUILD_PREFIX}' package src/map-*.dpkdir

maps: ${DATA_ACTION}-maps

prepare-resources:
	cd '${DATA_DIR}' && urcheon prepare src/res-*_src.dpkdir src/tex-*_src.dpkdir src/unvanquished_src.dpkdir

build-resources: prepare-resources
	cd '${DATA_DIR}' && urcheon --build-prefix='${DATA_BUILD_PREFIX}' build src/res-*_src.dpkdir src/tex-*_src.dpkdir src/unvanquished_src.dpkdir

package-resources: build-resources
	cd '${DATA_DIR}' && urcheon --build-prefix='${DATA_BUILD_PREFIX}' package src/res-*_src.dpkdir src/tex-*_src.dpkdir src/unvanquished_src.dpkdir

resources: ${DATA_ACTION}-resources

prepare-data: prepare-resources prepare-maps

build-data: build-resources build-maps

package-data: package-resources package-maps

data: ${DATA_ACTION}-data

build: bin data

clean-engine:
	${CMAKE_BIN} --build '${ENGINE_BUILD}' -- clean

clean-game:
	${CMAKE_BIN} --build '${GAME_BUILD}' -- clean

clean-bin: clean-engine clean-game

run-server: bin-server
	${DEBUG} \
	'${ENGINE_BUILD}/daemonded' \
		${ENGINE_LOG_ARGS} \
		${ENGINE_VMTYPE_ARGS} \
		-libpath '${GAME_BUILD}' \
		${DPKDIR_PAKPATH_ARGS} \
		${EXTRA_PAKPATH_ARGS} \
		${SERVER_ARGS} \
		${ARGS}

run-client: bin-client
	${DEBUG} \
	'${ENGINE_BUILD}/daemon' \
		${ENGINE_LOG_ARGS} \
		${ENGINE_VMTYPE_ARGS} \
		-libpath '${GAME_BUILD}' \
		${DPKDIR_PAKPATH_ARGS} \
		${EXTRA_PAKPATH_ARGS} \
		${SERVER_ARGS} \
		${CLIENT_ARGS} \
		${ARGS}

run-tty: bin-tty
	${DEBUG} \
	'${ENGINE_BUILD}/daemon-tty' \
		${ENGINE_LOG_ARGS} \
		${ENGINE_VMTYPE_ARGS} \
		-libpath '${GAME_BUILD}' \
		${DPKDIR_PAKPATH_ARGS} \
		${EXTRA_PAKPATH_ARGS} \
		${SERVER_ARGS} \
		${CLIENT_ARGS} \
		${ARGS}

run: run-client

load_map:
	$(MAKE) run ARGS="${ARGS} +devmap plat23"

load_game:
	$(MAKE) load_map ARGS="${ARGS} +delay 3f bot fill 5"

it: build load_game
