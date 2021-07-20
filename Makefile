# Copyright © 2017, Thomas Debesse
# Covered by BSD 3-Clause license
# See LICENSE.md for details

.DEFAULT_GOAL := build
.PHONY: clone-engine clone-vms clone-assets clone-bin clone pull-engine pull-vms pull-assets pull-bin pull engine vms bin assets maps resources textures data build run-server run-client run-tty run load_map load_game it

ROOT_DIR := $(shell dirname $(realpath $(lastword $(MAKEFILE_LIST))))
NPROC := $(shell nproc)

ENGINE_REPO := https://github.com/DaemonEngine/Daemon.git
GAMEVM_REPO := https://github.com/Unvanquished/Unvanquished.git
ASSETS_REPO := https://github.com/UnvanquishedAssets/UnvanquishedAssets.git

ENGINE_DIR := ${ROOT_DIR}/Daemon
GAMEVM_DIR := ${ROOT_DIR}/Unvanquished
ASSETS_DIR := ${ROOT_DIR}/UnvanquishedAssets

BUILD_DIR := ${ROOT_DIR}/build
EXDEPS_DIR := ${BUILD_DIR}/deps

ifeq ($(PKG),ON)
	PAK_PREFIX := pkg
else ifeq ($(PKG),OFF)
else ifeq ($(PKG),)
	PAK_PREFIX := test
endif

ifeq ($(BUILD),debug)
else ifeq ($(BUILD),reldeb)
else ifeq ($(BUILD),release)
else ifeq ($(BUILD),)
	BUILD := release
endif

ifeq ($(VM),nexe)
else ifeq ($(VM),exe)
else ifeq ($(VM),dll)
else ifeq ($(VM),)
	VM := dll
endif

ifeq ($(PREFIX),)
	PREFIX := default
endif

ifeq ($(COMPILER),)
	COMPILER := gcc
endif

ifeq ($(COMPILER),gcc)
	CMAKE_COMPILER_ARGS := -D'CMAKE_C_COMPILER'='/usr/bin/gcc' -D'CMAKE_CXX_COMPILER'='/usr/bin/g++'
	# -DCMAKE_C_LINK_EXECUTABLE='/usr/bin/ld' -DCMAKE_CXX_LINK_EXECUTABLE='/usr/bin/ld'
else ifeq ($(COMPILER),clang)
	CMAKE_COMPILER_ARGS := -D'CMAKE_C_COMPILER'='/usr/bin/clang' -D'CMAKE_CXX_COMPILER'='/usr/bin/clang++' # -D'CMAKE_EXE_LINKER_FLAGS_INIT'='-fuse-ld=lld' -D'CMAKE_MODULE_LINKER_FLAGS_INIT'='-fuse-ld=lld' -D'CMAKE_SHARED_LINKER_FLAGS_INIT'='-fuse-ld=lld'
	# -D'CMAKE_C_LINK_EXECUTABLE=/usr/bin/ld.lld' -D'CMAKE_CXX_LINK_EXECUTABLE=/usr/bin/ld.lld'
else ifeq ($(COMPILER),icc)
	CMAKE_COMPILER_ARGS := -D'CMAKE_TOOLCHAIN_FILE'='/opt/intel/oneapi/compiler/latest/linux/cmake/SYCL/FindIntelDPCPP.cmake' -'DCMAKE_C_COMPILER'='/opt/intel/oneapi/compiler/latest/linux/bin/clang' -D'CMAKE_CXX_COMPILER'='/opt/intel/oneapi/compiler/latest/linux/bin/clang++' -D'CMAKE_EXE_LINKER_FLAGS_INIT'='-fuse-ld=lld' -D'CMAKE_MODULE_LINKER_FLAGS_INIT'='-fuse-ld=lld' -D'CMAKE_SHARED_LINKER_FLAGS_INIT'='-fuse-ld=lld'
else
	CMAKE_COMPILER_ARGS :=
endif

ifeq ($(LTO),ON)
else ifeq ($(LTO),OFF)
else ifeq ($(LTO),)
	LTO := OFF
endif

GDB :=

ifeq ($(BUILD),release)
	CMAKE_DEBUG_ARGS := -D'USE_BREAKPAD'='OFF' -D'CMAKE_BUILD_TYPE'='Release' -D'USE_DEBUG_OPTIMIZE'='OFF'
else ifeq ($(BUILD),debug)
	CMAKE_DEBUG_ARGS := -D'USE_BREAKPAD'='OFF' -D'CMAKE_BUILD_TYPE'='Debug' -D'USE_DEBUG_OPTIMIZE'='OFF' -D'CMAKE_EXE_LINKER_FLAGS'='-lprofiler -ltcmalloc'

	# Hardcode that .gdbinit.txt path since “auto-load safe-path” usually prevents loading .gdbinit from current dir
	# Use another name to prevent printing useless warnings saying it will not loaded since we force it to be loaded
	GDB := gdb -x .gdbinit.txt -args
else ifeq ($(BUILD),reldeb)
	CMAKE_DEBUG_ARGS := -D'USE_BREAKPAD'='OFF' -D'CMAKE_BUILD_TYPE'='RelWithDebInfo' -D'USE_DEBUG_OPTIMIZE'='ON'
endif

GAMEVM_SYMLINK :=

ifeq ($(VM),dll)
	VM_TYPE := 3
	CMAKE_GAMEVM_ARGS := -D'BUILD_GAME_NACL'='OFF' -D'BUILD_GAME_NACL_NEXE'='OFF' -D'BUILD_GAME_NATIVE_EXE'='OFF' -D'BUILD_GAME_NATIVE_DLL'='ON'
else ifeq ($(VM),exe)
	VM_TYPE := 2
	CMAKE_GAMEVM_ARGS := -D'BUILD_GAME_NACL'='OFF' -D'BUILD_GAME_NACL_NEXE'='OFF' -D'BUILD_GAME_NATIVE_EXE'='ON' -D'BUILD_GAME_NATIVE_DLL'='OFF'
else
	VM_TYPE := 1
	CMAKE_GAMEVM_ARGS := -D'BUILD_GAME_NACL'='ON' -D'BUILD_GAME_NACL_NEXE'='ON' -D'BUILD_GAME_NATIVE_EXE'='OFF' -D'BUILD_GAME_NATIVE_DLL'='OFF'
	GAMEVM_LINK := vms-symlink
endif

ifeq ($(LTO),ON)
	LINK := lto
else
	LINK := default
endif

ifeq ($(VM),nexe)
	VM_LINK := default
	VM_LTO := OFF
	VM_COMPILER := nacl
else
	VM_LINK := ${LINK}
	VM_LTO := $(LTO)
	VM_COMPILER := ${COMPILER}
endif

ENGINE_BUILD := ${BUILD_DIR}/engine/${PREFIX}-${COMPILER}-${LINK}-${BUILD}-exe
GAMEVM_BUILD := ${BUILD_DIR}/vms/${PREFIX}-${VM_COMPILER}-${VM_LINK}-${BUILD}-${VM}

ASSETS_BUILD_PREFIX := ${BUILD_DIR}/assets
ASSETS_BUILD := ${ASSETS_BUILD_PREFIX}/${PAK_PREFIX}

ENGINE_VMTYPE_ARGS := -set vm.cgame.type ${VM_TYPE} -set vm.sgame.type ${VM_TYPE}

ENGINE_DEBUG_ARGS := -set logs.suppression.enabled 0 -set logs.logLevel.default debug -set logs.logLevel.audio debug -set language en -set developer 1

ENGINE_OTHER_ARGS := ${HOME_PATH}

EXTRA_PAKPATHS := $(shell [ -f .pakpaths ] && ( grep -v '\#' .pakpaths | sed -e 's/^/-pakpath /' | tr '\n' ' '))

clone-engine:
	(! [ -d '${ENGINE_DIR}' ] && git clone '${ENGINE_REPO}' '${ENGINE_DIR}') || true

clone-vms:
	(! [ -d '${GAMEVM_DIR}' ] && git clone '${GAMEVM_REPO}' '${GAMEVM_DIR}') || true

clone-assets:
	(! [ -d '${ASSETS_DIR}' ] && git clone '${ASSETS_REPO}' '${ASSETS_DIR}') || true
	make -C '${ASSETS_DIR}' clone

clone-bin: clone-engine clone-vms

clone: clone-bin clone-assets

pull-engine:
	cd '${ENGINE_DIR}' && (git remote | grep '^upstream$$' || git remote add upstream '${ENGINE_REPO}') || true
	cd '${ENGINE_DIR}' && git checkout master && git pull upstream master

pull-vms:
	cd '${GAMEVM_DIR}' && (git remote | grep '^upstream$$' || git remote add upstream '${GAMEVM_REPO}') || true
	cd '${GAMEVM_DIR}' && git checkout master && git pull upstream master

pull-assets:
	cd '${ASSETS_DIR}' && (git remote | grep '^upstream$$' || git remote add upstream '${ASSETS_REPO}') || true
	cd '${ASSETS_DIR}' && git checkout master && git pull upstream master
	make -C '${ASSETS_DIR}' pull

pull-bin: pull-engine pull-vms

pull: pull-bin pull-assets

configure-engine:
	cmake '${ENGINE_DIR}' -B'${ENGINE_BUILD}' \
		${CMAKE_COMPILER_ARGS} \
		${CMAKE_DEBUG_ARGS} \
		${CMAKE} \
		-D'USE_LTO'='${LTO}' \
		-D'EXTERNAL_DEPS_DIR'='${EXDEPS_DIR}' \
		-D'BUILD_SERVER'='ON' -D'BUILD_CLIENT'='ON' -D'BUILD_TTY_CLIENT'='ON' \
		-G'Unix Makefiles'

engine-server: configure-engine
	cmake --build '${ENGINE_BUILD}' -- -j'${NPROC}' server

engine-client: configure-engine
	cmake --build '${ENGINE_BUILD}' -- -j'${NPROC}' client

engine-tty: configure-engine
	cmake --build '${ENGINE_BUILD}' -- -j'${NPROC}' ttyclient

configure-vms:
	cmake '${GAMEVM_DIR}' -B'${GAMEVM_BUILD}' \
		${CMAKE_COMPILER_ARGS} \
		${CMAKE_DEBUG_ARGS} \
		${CMAKE_GAMEVM_ARGS} \
		${CMAKE} \
		-D'USE_LTO'='${VM_LTO}' \
		-D'EXTERNAL_DEPS_DIR'='${EXDEPS_DIR}' \
		-D'BUILD_SERVER'='OFF' -D'BUILD_CLIENT'='OFF' -D'BUILD_TTY_CLIENT'='OFF' \
		-D'BUILD_SGAME'='ON' -D'BUILD_CGAME'='ON' \
		-D'DAEMON_DIR'='${ENGINE_DIR}' \
		-G'Unix Makefiles'

vms-symlink:
	ln -sfv ${ENGINE_BUILD}/irt_core-x86_64.nexe ${GAMEVM_BUILD}/irt_core-x86_64.nexe
	ln -sfv ${ENGINE_BUILD}/nacl_helper_bootstrap ${GAMEVM_BUILD}/nacl_helper_bootstrap
	ln -sfv ${ENGINE_BUILD}/nacl_loader ${GAMEVM_BUILD}/nacl_loader

vms: configure-vms ${GAMEVM_SYMLINK}
	cmake --build '${GAMEVM_BUILD}' -- -j'${NPROC}'

engine: engine-server engine-client engine-tty

bin: engine vms

assets:
	make -C '${ASSETS_DIR}' BUILD_PREFIX='${ASSETS_BUILD_PREFIX}' build

maps:
	make -C '${ASSETS_DIR}' BUILD_PREFIX='${ASSETS_BUILD_PREFIX}' build_maps

resources:
	make -C '${ASSETS_DIR}' BUILD_PREFIX='${ASSETS_BUILD_PREFIX}' build_resources

textures:
	make -C '${ASSETS_DIR}' BUILD_PREFIX='${ASSETS_BUILD_PREFIX}' build_textures

data: assets

build: bin data

clean-engine:
	cmake --build '${ENGINE_BUILD}' -- clean

clean-vms:
	cmake --build '${GAMEVM_BUILD}' -- clean

clean-bin: clean-engine clean-vms

run-server: engine-server vms
	${GDB} \
	'${ENGINE_BUILD}/daemonded' \
		${ENGINE_DEBUG_ARGS} \
		${ENGINE_VMTYPE_ARGS} \
		${ENGINE_OTHER_ARGS} \
		-libpath '${GAMEVM_BUILD}' \
		-pakpath '${ASSETS_BUILD}' \
		${EXTRA_PAKPATHS} \
		${ARGS}

run-client: engine-client vms
	${GDB} \
	'${ENGINE_BUILD}/daemon' \
		${ENGINE_DEBUG_ARGS} \
		${ENGINE_VMTYPE_ARGS} \
		${ENGINE_OTHER_ARGS} \
		-libpath '${GAMEVM_BUILD}' \
		-pakpath '${ASSETS_BUILD}' \
		${EXTRA_PAKPATHS} \
		${ARGS}

run-tty: engine-tty vms
	${GDB} \
	'${ENGINE_BUILD}/daemon-tty' \
		${ENGINE_DEBUG_ARGS} \
		${ENGINE_VMTYPE_ARGS} \
		-libpath '${GAMEVM_BUILD}' \
		-pakpath '${ASSETS_BUILD}' \
		${EXTRA_PAKPATHS} \
		${ARGS}

run: run-client

load_map:
	$(MAKE) run ARGS="${ARGS} +devmap plat23"

load_game:
	$(MAKE) load_map ARGS="${ARGS} +delay 3f bot fill 5"

it: build load_game
