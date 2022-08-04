# Copyright © 2017, Thomas Debesse
# Covered by BSD 3-Clause license
# See LICENSE.md for details

.DEFAULT_GOAL := build
.PHONY: assets bin bin-client bin-server bin-tty build build-assets build-maps build-resources build-textures clean-bin clean-engine clean-vms clone clone-assets clone-bin clone-engine clone-vms configure-engine configure-vms data engine engine-client engine-server engine-tty it maps package-assets package-maps package-resources package-textures prepare-assets prepare-maps prepare-resources prepare-textures pull pull-assets pull-bin pull-engine pull-vms resources run run-client run-server run-tty set-current-engine set-current-vms textures vms

ROOT_DIR := $(shell dirname $(realpath $(lastword $(MAKEFILE_LIST))))
NPROC := $(shell nproc)

ENGINE_REPO := https://github.com/DaemonEngine/Daemon.git
VM_REPO := https://github.com/Unvanquished/Unvanquished.git
ASSETS_REPO := https://github.com/UnvanquishedAssets/UnvanquishedAssets.git

ENGINE_DIR := ${ROOT_DIR}/Daemon
VM_DIR := ${ROOT_DIR}/Unvanquished
ASSETS_DIR := ${ROOT_DIR}/UnvanquishedAssets

BUILD_DIR := ${ROOT_DIR}/build
EXDEPS_DIR := ${BUILD_DIR}/deps

CLIENT_ARGS := -set client.allowRemotePakdir on
SERVER_ARGS := -set sv_pure 0

SYSTEM := $(shell uname -s)

LN_BIN := ln
ifeq ($(SYSTEM),Darwin)
	LN_BIN := gln
endif

ifeq ($(PREFIX),)
	PREFIX := default
endif

ifeq ($(DPK),ON)
	PAK_PREFIX := pkg
else ifeq ($(DPK),OFF)
else ifeq ($(DPK),)
	PAK_PREFIX := test
endif

ifeq ($(VM),nexe)
else ifeq ($(VM),exe)
else ifeq ($(VM),dll)
else ifeq ($(VM),)
	VM := nexe
else
	$(error Bad VM value: $(VM))
endif

ifeq ($(BUILD),Debug)
else ifeq ($(BUILD),RelWithDebInfo)
else ifeq ($(BUILD),Release)
else ifeq ($(BUILD),)
	BUILD := RelWithDebInfo
else
	$(error Bad BUILD value: $(VM))
endif

ifeq ($(COMPILER),)
	COMPILER := gcc
	COMPILER_SLUG := $(shell gcc --version 2>/dev/null | if grep -q clang; then echo clang; else echo gcc; fi)
endif

CMAKE_FUSELD_ARGS :=

ifneq ($(FUSELD),)
	CMAKE_FUSELD_ARGS := -D'CMAKE_EXE_LINKER_FLAGS_INIT'='-fuse-ld=${FUSELD}' -D'CMAKE_MODULE_LINKER_FLAGS_INIT'='-fuse-ld=${FUSELD}' -D'CMAKE_SHARED_LINKER_FLAGS_INIT'='-fuse-ld=${FUSELD}'
endif

ifeq ($(COMPILER),gcc)
	CMAKE_COMPILER_ARGS := -D'CMAKE_C_COMPILER'='gcc' -D'CMAKE_CXX_COMPILER'='g++'
else ifeq ($(COMPILER),clang)
	CMAKE_COMPILER_ARGS := -D'CMAKE_C_COMPILER'='clang' -D'CMAKE_CXX_COMPILER'='clang++'
else ifeq ($(COMPILER),icc)
	CMAKE_COMPILER_ARGS := -D'CMAKE_C_COMPILER'='/opt/intel/oneapi/compiler/latest/linux/bin/clang' -D'CMAKE_CXX_COMPILER'='/opt/intel/oneapi/compiler/latest/linux/bin/clang++'
else
	CMAKE_COMPILER_ARGS :=
endif

CMAKE_CC :=

ifneq ($(CC),)
	CMAKE_CC := -D'CMAKE_C_COMPILER'='$(CC)'
endif

CMAKE_CXX :=

ifneq ($(CXX),)
	CMAKE_CXX := -D'CMAKE_CXX_COMPILER'='$(CXX)'
endif

CMAKE_COMPILER_ARGS := ${CMAKE_COMPILER_ARGS} ${CMAKE_CC} ${CMAKE_CXX}

CMAKE_COMPILER_FLAGS :=

ifneq ($(FLAGS),)
	CMAKE_COMPILER_FLAGS := -D'CMAKE_C_FLAGS'='${FLAGS}' -D'CMAKE_CXX_FLAGS'='${FLAGS}'
endif

ifeq ($(LTO),OFF)
else ifeq ($(LTO),ON)
else ifeq ($(LTO),)
	LTO := ON
else
	$(error Bad LTO value: $(VM))
endif

ifeq ($(CMAKE_BIN),)
	CMAKE_BIN := cmake
endif

DEBUG :=

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
endif

ifeq ($(VM),dll)
	VM_TYPE := 3
	CMAKE_VM_ARGS := -D'BUILD_GAME_NACL'='OFF' -D'BUILD_GAME_NACL_NEXE'='OFF' -D'BUILD_GAME_NATIVE_EXE'='OFF' -D'BUILD_GAME_NATIVE_DLL'='ON'
else ifeq ($(VM),exe)
	VM_TYPE := 2
	CMAKE_VM_ARGS := -D'BUILD_GAME_NACL'='OFF' -D'BUILD_GAME_NACL_NEXE'='OFF' -D'BUILD_GAME_NATIVE_EXE'='ON' -D'BUILD_GAME_NATIVE_DLL'='OFF'
else ifeq ($(VM),nexe)
	VM_TYPE := 1
	CMAKE_VM_ARGS := -D'BUILD_GAME_NACL'='ON' -D'BUILD_GAME_NACL_NEXE'='ON' -D'BUILD_GAME_NATIVE_EXE'='OFF' -D'BUILD_GAME_NATIVE_DLL'='OFF'
endif

ifeq ($(LTO),ON)
	LINK := lto
else
	LINK := nolto
endif

ifeq ($(VM),nexe)
	VM_LINK := nolto
	VM_LTO := OFF
	VM_COMPILER_SLUG := nacl
	CMAKE_VM_COMPILER_ARGS :=
	CMAKE_VM_FUSELD_ARGS :=
else
	VM_LINK := ${LINK}
	VM_LTO := $(LTO)
	VM_COMPILER_SLUG := ${COMPILER_SLUG}
	CMAKE_VM_COMPILER_ARGS := $(CMAKE_COMPILER_ARGS)
	CMAKE_VM_FUSELD_ARGS := $(CMAKE_FUSELD_ARGS)
endif

ENGINE_PREFIX := ${PREFIX}-${COMPILER_SLUG}-${LINK}-${BUILD_SLUG}-exe
VM_PREFIX := ${PREFIX}-${VM_COMPILER_SLUG}-${VM_LINK}-${BUILD_SLUG}-${VM}

ENGINE_BUILD := ${BUILD_DIR}/engine/${ENGINE_PREFIX}
VM_BUILD := ${BUILD_DIR}/vms/${VM_PREFIX}

ASSETS_BUILD_PREFIX := ${BUILD_DIR}/assets
ASSETS_BUILD := ${ASSETS_BUILD_PREFIX}/${PAK_PREFIX}

ENGINE_VMTYPE_ARGS := -set vm.cgame.type ${VM_TYPE} -set vm.sgame.type ${VM_TYPE}

ifeq ($(LOG),Debug)
	ENGINE_LOG_ARGS := -set logs.suppression.enabled 0 -set logs.level.default debug -set logs.level.audio debug -set logs.level.glconfig debug -set developer 1
else
	ENGINE_LOG_ARGS := -set logs.suppression.enabled 1 -set logs.level.default notice -set logs.level.audio notice  -set logs.level.glconfig notice -set developer 0
endif

DPKDIR_PAKPATH_ARGS :=

ifneq ($(DPKDIR),OFF)
		DPKDIR_PAKPATH_ARGS := -pakpath '${ASSETS_BUILD}'
endif

EXTRA_PAKPATHS := $(shell [ -f .pakpaths ] && ( grep -v '\#' .pakpaths | sed -e 's/^/-pakpath /' | tr '\n' ' '))

EXTRA_PAKPATH_ARGS :=
ifneq ($(EXTRA_PAKPATHS),)
	EXTRA_PAKPATH_ARGS := -pakpath ${EXTRA_PAKPATHS}
endif

clone-engine:
	(! [ -d '${ENGINE_DIR}' ] && git clone '${ENGINE_REPO}' '${ENGINE_DIR}') || true

clone-vms:
	(! [ -d '${VM_DIR}' ] && git clone '${VM_REPO}' '${VM_DIR}') || true

clone-assets:
	(! [ -d '${ASSETS_DIR}' ] && git clone '${ASSETS_REPO}' '${ASSETS_DIR}') || true
	cd '${ASSETS_DIR}' && git submodule update --init --recursive

clone-bin: clone-engine clone-vms

clone: clone-bin clone-assets

pull-engine:
	cd '${ENGINE_DIR}' && git checkout master && git pull origin master

pull-vms:
	cd '${VM_DIR}' && git checkout master && git pull origin master

pull-assets:
	cd '${ASSETS_DIR}' && git checkout master && git pull origin master
	cd '${ASSETS_DIR}' && git submodule foreach pull origin master

pull-bin: pull-engine pull-vms

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

engine-server: configure-engine set-current-engine
	${CMAKE_BIN} --build '${ENGINE_BUILD}' -- -j'${NPROC}' server

engine-client: configure-engine set-current-engine
	${CMAKE_BIN} --build '${ENGINE_BUILD}' -- -j'${NPROC}' client

engine-tty: configure-engine set-current-engine
	${CMAKE_BIN} --build '${ENGINE_BUILD}' -- -j'${NPROC}' ttyclient

configure-vms:
	${CMAKE_BIN} '${VM_DIR}' -B'${VM_BUILD}' \
		${CMAKE_VM_COMPILER_ARGS} \
		${CMAKE_VM_FUSELD_ARGS} \
		${CMAKE_DEBUG_ARGS} \
		${CMAKE_VM_ARGS} \
		${CMAKE_COMPILER_FLAGS} \
		${CMAKE} \
		-D'USE_LTO'='${VM_LTO}' \
		-D'EXTERNAL_DEPS_DIR'='${EXDEPS_DIR}' \
		-D'BUILD_SERVER'='OFF' -D'BUILD_CLIENT'='OFF' -D'BUILD_TTY_CLIENT'='OFF' \
		-D'BUILD_SGAME'='ON' -D'BUILD_CGAME'='ON' \
		-D'DAEMON_DIR'='${ENGINE_DIR}' \
		-G'Unix Makefiles'
	echo "${VM_TYPE}" > "${VM_BUILD}/vm_type.txt"

set-current-vms:
	${LN_BIN} --verbose --symbolic --force --no-target-directory ${VM_PREFIX} build/vms/current

vms: configure-vms set-current-vms
	${CMAKE_BIN} --build '${VM_BUILD}' -- -j'${NPROC}'
	${LN_BIN} --verbose --symbolic --force ${ENGINE_BUILD}/irt_core-x86_64.nexe ${VM_BUILD}/irt_core-x86_64.nexe
	${LN_BIN} --verbose --symbolic --force ${ENGINE_BUILD}/nacl_helper_bootstrap ${VM_BUILD}/nacl_helper_bootstrap
	${LN_BIN} --verbose --symbolic --force ${ENGINE_BUILD}/nacl_loader ${VM_BUILD}/nacl_loader

bin-client: engine-client vms

bin-server: engine-server vms

bin-tty: engine-tty vms

engine: engine-server engine-client engine-tty

bin: engine vms

prepare-maps:
	cd '${ASSETS_DIR}' && urcheon prepare --build-prefix='${ASSETS_BUILD_PREFIX}' src/map-*.dpkdir

build-maps: prepare-maps
	cd '${ASSETS_DIR}' && urcheon build --build-prefix='${ASSETS_BUILD_PREFIX}' src/map-*.dpkdir

package-maps: build-maps
	cd '${ASSETS_DIR}' && urcheon package --package-prefix='${ASSETS_BUILD_PREFIX}' src/map-*.dpkdir

maps: package-maps

prepare-resources:
	cd '${ASSETS_DIR}' && urcheon prepare --build-prefix='${ASSETS_BUILD_PREFIX}' src/res-*.dpkdir

build-resources: prepare-resources
	cd '${ASSETS_DIR}' && urcheon build --build-prefix='${ASSETS_BUILD_PREFIX}' src/res-*.dpkdir

package-resources: build-resources
	cd '${ASSETS_DIR}' && urcheon package --package-prefix='${ASSETS_BUILD_PREFIX}' src/res-*.dpkdir

resources: package-resources

prepare-textures:
	cd '${ASSETS_DIR}' && urcheon prepare --build-prefix='${ASSETS_BUILD_PREFIX}' src/tex-*.dpkdir

build-textures: prepare-textures
	cd '${ASSETS_DIR}' && urcheon build --build-prefix='${ASSETS_BUILD_PREFIX}' src/tex-*.dpkdir

package-textures: build-textures
	cd '${ASSETS_DIR}' && urcheon package --package-prefix='${ASSETS_BUILD_PREFIX}' src/tex-*.dpkdir

textures: package-textures

prepare-assets:
	cd '${ASSETS_DIR}' && urcheon prepare --build-prefix='${ASSETS_BUILD_PREFIX}' src/*.dpkdir

build-assets: prepare-assets
	cd '${ASSETS_DIR}' && urcheon build --build-prefix='${ASSETS_BUILD_PREFIX}' src/*.dpkdir

package-assets: build-assets
	cd '${ASSETS_DIR}' && urcheon package --build-prefix='${ASSETS_BUILD_PREFIX}' src/*.dpkdir

assets: package-assets

data: assets

build: bin data

clean-engine:
	${CMAKE_BIN} --build '${ENGINE_BUILD}' -- clean

clean-vms:
	${CMAKE_BIN} --build '${VM_BUILD}' -- clean

clean-bin: clean-engine clean-vms

run-server: bin-server
	${DEBUG} \
	'${ENGINE_BUILD}/daemonded' \
		${ENGINE_LOG_ARGS} \
		${ENGINE_VMTYPE_ARGS} \
		-libpath '${VM_BUILD}' \
		${DPKDIR_PAKPATH_ARGS} \
		${EXTRA_PAKPATH_ARGS} \
		${SERVER_ARGS} \
		${ARGS}

run-client: bin-client
	${DEBUG} \
	'${ENGINE_BUILD}/daemon' \
		${ENGINE_LOG_ARGS} \
		${ENGINE_VMTYPE_ARGS} \
		-libpath '${VM_BUILD}' \
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
		-libpath '${VM_BUILD}' \
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
