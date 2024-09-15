# Copyright © 2023, Thomas Debesse
# Covered by BSD 3-Clause license
# See LICENSE.md for details

.DEFAULT_GOAL := build
.PHONY: data bin bin-client bin-server bin-tty build build-data build-maps build-resources clean-bin clean-engine clean-game clone clone-data clone-bin clone-game configure-engine configure-game data engine engine-client engine-server engine-tty it maps package-data package-maps package-resources prepare-data prepare-maps prepare-resources pull pull-data pull-bin pull-engine pull-game resources run run-client run-server run-tty set-current set-current-engine set-current-game engine-windows-extra engine-other-extra engine-extra game game-nexe-extra game-nexe-windows-extra game-nexe-other-extra game-dll-extra game-exe-extra game-extra bin-extra build-client build-server build-tty

ROOT_DIR := $(shell dirname $(realpath $(lastword $(MAKEFILE_LIST))))

GAME_REPO := https://github.com/Unvanquished/Unvanquished.git
DATA_REPO := https://github.com/UnvanquishedAssets/UnvanquishedAssets.git

GAME_DIR := ${ROOT_DIR}/Unvanquished
ENGINE_DIR := ${GAME_DIR}/daemon
DATA_DIR := ${ROOT_DIR}/UnvanquishedAssets

BUILD_DIR := ${ROOT_DIR}/build
EXDEPS_DIR := ${BUILD_DIR}/deps

CLIENT_ARGS := -set common.pedanticShutdown on -set client.allowRemotePakDir on
SERVER_ARGS := -set common.pedanticShutdown on -set sv_pure 0

NOW := $(shell date -u '+%Y%m%d-%H%M%S')

SYSTEM := $(shell uname -s | tr '[:upper:]' '[:lower:]' | sed -e 's/[^a-z0-9]//g')

ifeq ($(SYSTEM),darwin)
    LN_BIN := gln
    NPROC_CMD := sysctl -n hw.logicalcpu
else ifeq ($(SYSTEM),freebsd)
    LN_BIN := gln
    NPROC_CMD := sysctl -n hw.ncpu
    # Mold produce weird bugs on FreeBSD, like the game not being loadable
    # by the engine, whatever the format (dll, exe, nexe).
    MOLD := OFF
else
    LN_BIN := ln
    NPROC_CMD := nproc
endif

ifeq ($(NPROC),)
    NPROC := $(shell ${NPROC_CMD})
endif

ifeq ($(CMAKE_BIN),)
    CMAKE_BIN := cmake
endif

LN_CMD := '${LN_BIN}' --verbose --symbolic --force 

# HACK: Pass every argument after "run" goal as game options.
# This is only done if ARGS option is not set (which is safer to use).
# The -- option should be used so -options are not interpreted by make.
# Example:
# make data run -- -set sv_hostname "test server" +devmap plat23
ifeq (run,$(findstring run,$(MAKECMDGOALS)))
    ifeq ($(ARGS),)
        # https://stackoverflow.com/a/37483943/9131399
        _pos = $(if $(findstring $1,$2),$(call _pos,$1,$(wordlist 2,$(words $2),$2),x $3),$3)
        # return the position after the word
        posafter = $(words $(call _pos,$1,$2) x)

        # https://stackoverflow.com/a/14061796/9131399
        # find "run" position
        RUN_POSAFTER :=  $(call posafter,run,$(MAKECMDGOALS))
        # use the rest as arguments for "run"
        ARGS := $(wordlist $(RUN_POSAFTER),$(words $(MAKECMDGOALS)),$(MAKECMDGOALS))
        # and turn them into do-nothing targets
        $(eval $(ARGS):;@:)
    endif
endif

ifeq ($(PREFIX),)
    PREFIX := default
endif

ifeq ($(BUILD),ON)
else ifeq ($(BUILD),OFF)
else ifeq ($(BUILD),)
    BUILD := ON
else
    $(error Bad BUILD value: $(VM))
endif

ifeq ($(BUILD),OFF)
    NOBUILD_SUFFIX := -nobuild
endif

ifeq ($(DPK),)
    DPK := OFF
endif

ifeq ($(DPK),ON)
    PAK_PREFIX := pkg
    DATA_ACTION := package
else ifeq ($(DPK),OFF)
    PAK_PREFIX := _pakdir/pkg
    DATA_ACTION := build
endif

ifeq ($(VM),nexe)
else ifeq ($(VM),exe)
else ifeq ($(VM),dll)
else ifeq ($(VM),)
    VM := dll
else
    $(error Bad VM value: $(VM))
endif

ifeq ($(VM),nexe)
    ifeq ($(NEXE),)
        NEXE := native
    endif
endif

ifeq ($(MARCH),)
    MARCH := generic
endif

ifeq ($(MARCH),generic)
    CMAKE_ARCH_ARGS := -D'USE_CPU_GENERIC_ARCHITECTURE'='ON' -D'USE_CPU_RECOMMENDED_FEATURES'='ON'
else ifeq ($(MARCH),lowend)
    CMAKE_ARCH_ARGS := -D'USE_CPU_GENERIC_ARCHITECTURE'='ON' -D'USE_CPU_RECOMMENDED_FEATURES'='OFF'
else ifeq ($(MARCH),native)
    CMAKE_ARCH_ARGS := -D'USE_CPU_GENERIC_ARCHITECTURE'='OFF' -D'USE_CPU_RECOMMENDED_FEATURES'='OFF'
    ARCH_FLAGS := -march=native -mtune=native
else
    ARCH_FLAGS := -march=$(MARCH)
endif

ifeq ($(LD_BIN),)
    CMAKE_USELD_ARGS := -D'CMAKE_EXE_LINKER_FLAGS_INIT'= \
        -D'CMAKE_MODULE_LINKER_FLAGS_INIT'= \
        -D'CMAKE_SHARED_LINKER_FLAGS_INIT'=
else
    CMAKE_USELD_ARGS := -D'CMAKE_EXE_LINKER_FLAGS_INIT'='-fuse-ld=${LD_BIN}' \
        -D'CMAKE_MODULE_LINKER_FLAGS_INIT'='-fuse-ld=${LD_BIN}' \
        -D'CMAKE_SHARED_LINKER_FLAGS_INIT'='-fuse-ld=${LD_BIN}'
endif

getCompilerVersion = $(word 2,$(subst -, ,$1))

ifeq ($(COMPILER),)
    COMPILER := $(shell cc --version 2>/dev/null | if grep -q clang; then echo clang; else echo gcc; fi)
endif

ifeq ($(COMPILER),gcc)
    CC_BIN := gcc
    CXX_BIN := g++
else ifeq ($(findstring gcc-,$(COMPILER)),gcc-)
    COMPILER_VERSION := $(call getCompilerVersion,$(COMPILER))
    CC_BIN := gcc-$(COMPILER_VERSION)
    CXX_BIN := g++-$(COMPILER_VERSION)
else ifeq ($(COMPILER),armclang)
    CC_BIN := $(shell ls /opt/arm/arm-linux-compiler-*/bin/armclang | sort | tail -n 1)
    CXX_BIN := $(shell dirname "${CC_BIN}")/armclang++
else ifeq ($(findstring armclang-,$(COMPILER)),armclang-)
    COMPILER_VERSION := $(call getCompilerVersion,$(COMPILER))
    CC_BIN := $(shell ls "/opt/arm/arm-linux-compiler-${COMPILER_VERSION}"_*/bin/armclang | sort | tail -n 1)
    CXX_BIN := $(shell dirname "${CC_BIN}")/armclang++
else ifeq ($(COMPILER),clang)
    CC_BIN := clang
    CXX_BIN := clang++
else ifeq ($(findstring clang-,$(COMPILER)),clang-)
    COMPILER_VERSION := $(call getCompilerVersion,$(COMPILER))
    CC_BIN := clang-$(COMPILER_VERSION)
    CXX_BIN := clang++-$(COMPILER_VERSION)
else ifeq ($(COMPILER),mingw)
    CC_BIN := x86_64-w64-mingw32-gcc
    CXX_BIN := x86_64-w64-mingw32-g++
    TOOLCHAIN := cmake/cross-toolchain-mingw64.cmake
    ENGINE_EXT := .exe
else ifeq ($(COMPILER),zig)
    # You may have to do:
    #   sudo ln -s /usr/include/asm-generic/ /usr/include/asm
    # if you get:
    #   /usr/include/linux/errno.h:1:10: fatal error: 'asm/errno.h' file not found
    CC_BIN := zig;cc
    CXX_BIN := zig;c++
else ifeq ($(COMPILER),icc)
    CC_BIN := $(shell ls /opt/intel/oneapi/compiler/*/linux/bin/intel64/icc | sort | tail -n1)
    CXX_BIN := $(shell ls /opt/intel/oneapi/compiler/*/linux/bin/intel64/icpc | sort | tail -n1)
    export LD_LIBRARY_PATH += :$(shell ls -d /opt/intel/oneapi/compiler/*/linux/compiler/lib/intel64_lin | sort | tail -n1)
    # remark #10441: The Intel(R) C++ Compiler Classic (ICC) is deprecated and will be removed from product release in the second half of 2023. The Intel(R) oneAPI DPC++/C++ Compiler (ICX) is the recommended compiler moving forward. Please transition to use this compiler. Use '-diag-disable=10441' to disable this message.
    # remark #11074: Inlining inhibited by limit max-size
    # remark #11074: Inlining inhibited by limit max-total-size
    # remark #11076: To get full report use -qopt-report=4 -qopt-report-phase ipo
    # ICC is incompatible with /usr/include/c++/13 and later.
    NATIVE_C_COMPILER_FLAGS := -diag-disable=10441 -diag-disable=11074 -diag-disable=11076 -gcc-name=/usr/bin/gcc-12
    NATIVE_CXX_COMPILER_FLAGS := ${NATIVE_C_COMPILER_FLAGS} -gxx-name=/usr/bin/g++-12
    # ICC doesn't work correctly with mold.
    MOLD := OFF
else ifeq ($(findstring icc-,$(COMPILER)),icc-)
    COMPILER_VERSION := $(call getCompilerVersion,$(COMPILER))
    CC_BIN := /opt/intel/oneapi/compiler/${COMPILER_VERSION}/linux/bin/intel64/icc
    CXX_BIN := /opt/intel/oneapi/compiler/${COMPILER_VERSION}/linux/bin/intel64/icpc
    export LD_LIBRARY_PATH += :$(shell ls -d /opt/intel/oneapi/compiler/*/linux/compiler/lib/intel64_lin | sort | tail -n1)
    NATIVE_C_COMPILER_FLAGS := -diag-disable=10441 -diag-disable=11074 -diag-disable=11076 -gcc-name=/usr/bin/gcc-12
    NATIVE_CXX_COMPILER_FLAGS := ${NATIVE_C_COMPILER_FLAGS} -gxx-name=/usr/bin/g++-12
    # ICC doesn't work correctly with mold.
    MOLD := OFF
else ifeq ($(COMPILER),icx)
    CC_BIN := $(shell find /opt/intel/oneapi/compiler/latest/ -type f -name icx)
    CXX_BIN := $(shell dirname "${CC_BIN}")/icpx
    IMF_LIB := $(shell find /opt/intel/oneapi/compiler/latest/  -type f -name libimf.so)
    export LD_LIBRARY_PATH += :$(shell dirname "$(IMF_LIB)")
#    NATIVE_C_COMPILER_FLAGS := -Rdebug-disables-optimization
#    NATIVE_CXX_COMPILER_FLAGS := -Rdebug-disables-optimization
else ifeq ($(findstring icx-,$(COMPILER)),icx-)
    COMPILER_VERSION := $(call getCompilerVersion,$(COMPILER))
    CC_BIN := $(shell find "/opt/intel/oneapi/compiler/${COMPILER_VERSION}/" -type f -name icx)
    CXX_BIN := $(shell dirname "${CC_BIN}")/icpx
    IMF_LIB := $(shell find "/opt/intel/oneapi/compiler/${COMPILER_VERSION}/"  -type f -name libimf.so)
    export LD_LIBRARY_PATH += :$(shell dirname "$(IMF_LIB)")
#    NATIVE_C_COMPILER_FLAGS := -Rdebug-disables-optimization
#    NATIVE_CXX_COMPILER_FLAGS := -Rdebug-disables-optimization
else ifeq ($(COMPILER),aocc)
    CC_BIN := $(shell ls /opt/AMD/aocc-compiler-*/bin/clang | sort | tail -n1)
    CXX_BIN := $(shell dirname "${CC_BIN}")/clang++
    CPP_LIB := $(shell ls /opt/AMD/aocc-compiler-*/lib/libc++.so | sort | tail -n1)
    export LD_LIBRARY_PATH += $(shell dirname "${CPP_LIB}")
else ifeq ($(findstring aocc-,$(COMPILER)),aocc-)
    COMPILER_VERSION := $(call getCompilerVersion,$(COMPILER))
    CC_BIN := /opt/AMD/aocc-compiler-${COMPILER_VERSION}/bin/clang
    CXX_BIN := $(shell dirname "${CC_BIN}")/clang++
    export LD_LIBRARY_PATH += :/opt/AMD/aocc-compiler-${COMPILER_VERSION}/lib/
endif

ifeq ($(CLANG_LIBCPP),ON)
else ifeq ($(CLANG_LIBCPP),OFF)
else ifeq ($(CLANG_LIBCPP),)
    CLANG_LIBCPP := OFF
else
    $(error Bad CLANG_LIBCPP value: $(CLANG_LIBCPP))
endif

ifeq ($(CLANG_LIBCPP),ON)
    NATIVE_CXX_COMPILER_FLAGS := ${NATIVE_CXX_COMPILER_FLAGS} -stdlib=libc++
    NATIVE_LINKER_FLAGS := ${NATIVE_LINKER_FLAGS} -stdlib=libc++
endif

ifeq ($(CLANG_GCC),)
else
    NATIVE_COMPILER_FLAGS := ${NATIVE_COMPILER_FLAGS} --gcc-install-dir=/usr/lib/gcc/x86_64-linux-gnu/${CLANG_GCC}
endif

ifneq ($(CC_BIN),)
    CMAKE_C_COMPILER_ARGS := -D'CMAKE_C_COMPILER'='$(CC_BIN)'
endif

ifneq ($(CXX_BIN),)
    CMAKE_CXX_COMPILER_ARGS := -D'CMAKE_CXX_COMPILER'='$(CXX_BIN)'
endif

ifeq ($(MOLD),)
    MOLD_PATH := $(shell command -v mold || true)

    ifneq ($(MOLD_PATH),)
        MOLD := ON
    endif
else ifeq ($(MOLD),ON)
else ifeq ($(MOLD),OFF)
else
    $(error Bad MOLD value: $(MOLD))
endif

ifeq ($(MOLD),ON)
   MOLD_BIN := mold
   MOLD_CMD := '${MOLD_BIN}' --run
endif

NINJA_PATH := $(shell command -v ninja || true)

ifneq ($(NINJA_PATH),)
    GEN := Ninja
else
    GEN := Unix Makefiles
endif

ifeq ($(CCACHE),)
    CCACHE_PATH := $(shell command -v ccache || true)

    ifneq ($(CCACHE_PATH),)
        CCACHE := ON
    endif
else ifeq ($(CCACHE),ON)
else ifeq ($(CCACHE),OFF)
else
    $(error Bad CCACHE value: $(CCACHE))
endif

ifeq ($(CCACHE),ON)
    CCACHE_BIN := ccache
    CMAKE_C_COMPILER_ARGS += -D'CMAKE_C_COMPILER_LAUNCHER'='${CCACHE_BIN}'
    CMAKE_CXX_COMPILER_ARGS += -D'CMAKE_CXX_COMPILER_LAUNCHER'='${CCACHE_BIN}'
endif

CMAKE_COMPILER_ARGS := ${CMAKE_C_COMPILER_ARGS} ${CMAKE_CXX_COMPILER_ARGS}

ifeq ($(TCMALLOC),ON)
else ifeq ($(TCMALLOC),OFF)
else ifeq ($(TCMALLOC),)
    TCMALLOC := OFF
else
    $(error Bad TCMALLOC value: $(TCMALLOC))
endif

ifeq ($(TCMALLOC),ON)
    NATIVE_LINKER_FLAGS := ${NATIVE_LINKER_FLAGS} -ltcmalloc
endif

ifeq ($(TYPE),)
    TYPE := RelWithDebInfo
endif

ifeq ($(TYPE),Release)
    BUILD_TYPE := release
    CMAKE_DEBUG_ARGS := -D'USE_BREAKPAD'='OFF' -D'CMAKE_BUILD_TYPE'='Release' -D'USE_DEBUG_OPTIMIZE'='OFF'
else ifeq ($(TYPE),MinSizeRel)
    BUILD_TYPE := minsize
    CMAKE_DEBUG_ARGS := -D'USE_BREAKPAD'='OFF' -D'CMAKE_BUILD_TYPE'='MinSizeRel' -D'USE_DEBUG_OPTIMIZE'='OFF'
else ifeq ($(TYPE),Debug)
    BUILD_TYPE := debug
    CMAKE_DEBUG_ARGS := -D'USE_BREAKPAD'='OFF' -D'CMAKE_BUILD_TYPE'='Debug' -D'USE_DEBUG_OPTIMIZE'='OFF'
    NATIVE_COMPILER_FLAGS := ${NATIVE_COMPILER_FLAGS} -fno-omit-frame-pointer
    DEBUG := gdb
else ifeq ($(TYPE),Profile)
    BUILD_TYPE := profile
    CMAKE_DEBUG_ARGS := -D'USE_BREAKPAD'='OFF' -D'CMAKE_BUILD_TYPE'='Debug' -D'USE_DEBUG_OPTIMIZE'='ON'
    NATIVE_COMPILER_FLAGS := ${NATIVE_COMPILER_FLAGS} -fno-omit-frame-pointer
    DEBUG := gdb
else ifeq ($(TYPE),RelWithDebInfo)
    BUILD_TYPE := reldeb
    CMAKE_DEBUG_ARGS := -D'USE_BREAKPAD'='OFF' -D'CMAKE_BUILD_TYPE'='RelWithDebInfo' -D'USE_DEBUG_OPTIMIZE'='ON'
    DEBUG := gdb
else
    $(error Bad TYPE value: $(TYPE))
endif

ifeq ($(COMPILER),mingw)
    RUNNER := wine
    EXE_EXT := .exe
    export WINEPREFIX = $(shell realpath "${BUILD_DIR}/wine")
endif

ifeq ($(DEBUG),)
else ifeq ($(DEBUG),gdb)
    # Hardcode that .gdbinit.txt path since “auto-load safe-path” usually prevents loading .gdbinit from current dir
    # Use another name to prevent printing useless warnings saying it will not loaded since we force it to be loaded
    RUNNER := gdb -x .gdbinit.txt -args
else ifeq ($(DEBUG),gdbgui)
    RUNNER := pipx run gdbgui --args
else ifeq ($(DEBUG),lldb)
    RUNNER := lldb -s .lldbinit.txt --
else ifeq ($(DEBUG),winedbg)
    RUNNER := winedbg
else ifeq ($(DEBUG),nemiver)
    RUNNER := nemiver
else ifeq ($(DEBUG),alleyoop)
    RUNNER := alleyoop -R "${GAME_DIR}"
else ifeq ($(DEBUG),gprofng)
    RUNNER := gprofng collect app
else ifeq ($(DEBUG),valgrind)
    RUNNER := valgrind --tool=memcheck --num-callers=4 --track-origins=yes --time-stamp=yes --run-libc-freeres=yes --leak-check=full --leak-resolution=high --track-origins=yes --show-leak-kinds=all --log-file='logs/valgrind-${NOW}.log' --
else ifeq ($(DEBUG),heapusage)
    RUNNER := heapusage -m 0 -o 'logs/heapusage-${NOW}.log'
else ifeq ($(DEBUG),apitrace)
    RUNNER := apitrace trace --output='logs/apitrace-${NOW}.trace'
else ifeq ($(DEBUG),asan)
    # AddressSanitizer only builds with exe.
    # LeakSanitizer only works if program is built with Clang.
    # LeakSanitizer does not work under ptrace (strace, gdb, etc).
    NATIVE_COMPILER_FLAGS := ${NATIVE_COMPILER_FLAGS} -fsanitize=address -fno-omit-frame-pointer -fno-optimize-sibling-calls
    NATIVE_LINKER_FLAGS := ${NATIVE_LINKER_FLAGS} -fsanitize=address
else ifeq ($(DEBUG),lsan)
    NATIVE_COMPILER_FLAGS := ${NATIVE_COMPILER_FLAGS} -fsanitize=leak -fno-omit-frame-pointer -fno-optimize-sibling-calls
    NATIVE_LINKER_FLAGS := ${NATIVE_LINKER_FLAGS} -fsanitize=leak
else ifeq ($(DEBUG),msan)
    NATIVE_COMPILER_FLAGS := ${NATIVE_COMPILER_FLAGS} -fsanitize=memory -fno-omit-frame-pointer -fno-optimize-sibling-calls -fPIE
    NATIVE_LINKER_FLAGS := ${NATIVE_LINKER_FLAGS} -fsanitize=memory -pie
else ifeq ($(DEBUG),tsan)
    NATIVE_COMPILER_FLAGS := ${NATIVE_COMPILER_FLAGS} -fsanitize=thread
    NATIVE_LINKER_FLAGS := ${NATIVE_LINKER_FLAGS} -fsanitize=thread
else
    $(error Bad DEBUG value: $(DEBUG))
endif

ifeq ($(PROFILE),)
else ifeq ($(PROFILE),efence)
    NATIVE_LINKER_FLAGS := ${NATIVE_LINKER_FLAGS} -Wl,-no-as-needed -lefence
    export EF_ALLOW_MALLOC_0 = 1
else ifeq ($(PROFILE),gperftools)
    NATIVE_LINKER_FLAGS := ${NATIVE_LINKER_FLAGS} -Wl,-no-as-needed -lprofiler
    export CPUPROFILE = logs/gperftools-${NOW}.prof
else
    $(error Bad PROFILE value: $(PROFILE))
endif

NATIVE_C_COMPILER_FLAGS := ${NATIVE_COMPILER_FLAGS} ${NATIVE_C_COMPILER_FLAGS}
NATIVE_CXX_COMPILER_FLAGS := ${NATIVE_COMPILER_FLAGS} ${NATIVE_CXX_COMPILER_FLAGS}

CMAKE_ENGINE_COMPILER_FLAGS := \
    -D'CMAKE_C_FLAGS'='${ARCH_FLAGS} ${NATIVE_C_COMPILER_FLAGS} ${COMPILER_FLAGS} ${COMPILER_C_FLAGS}' \
    -D'CMAKE_CXX_FLAGS'='${ARCH_FLAGS} ${NATIVE_CXX_COMPILER_FLAGS} ${COMPILER_FLAGS} ${COMPILER_CXX_FLAGS}'

CMAKE_ENGINE_LINKER_FLAGS := -D'CMAKE_EXE_LINKER_FLAGS'='${NATIVE_LINKER_FLAGS} ${LINKER_FLAGS}'

ifeq ($(PCH),ON)
else ifeq ($(PCH),OFF)
else ifeq ($(PCH),)
    PCH := ON
else
    $(error Bad PCH value: $(PCH))
endif

ifeq ($(LTO),ON)
else ifeq ($(LTO),OFF)
else ifeq ($(LTO),)
    LTO := OFF
else
    $(error Bad LTO value: $(LTO))
endif

ifeq ($(LTO),ON)
    LINK := lto
else
    LINK := nolto
endif

ifeq ($(HARDENING),ON)
else ifeq ($(HARDENING),OFF)
else ifeq ($(HARDENING),)
    HARDENING := ON
else
    $(error Bad HARDENING value: $(HARDENING))
endif

ifeq ($(PEDANTIC),ON)
else ifeq ($(PEDANTIC),OFF)
else ifeq ($(PEDANTIC),)
    PEDANTIC := OFF
else
    $(error Bad PEDANTIC value: $(PEDANTIC))
endif

ifeq ($(WERROR),ON)
else ifeq ($(WERROR),OFF)
else ifeq ($(WERROR),)
    WERROR := OFF
else
    $(error Bad WERROR value: $(WERROR))
endif

ifeq ($(VM),dll)
    VM_TYPE := 3
    CMAKE_GAME_ARGS := \
        -D'BUILD_GAME_NACL'='OFF' \
        -D'BUILD_GAME_NACL_NEXE'='OFF' \
        -D'BUILD_GAME_NATIVE_EXE'='OFF' \
        -D'BUILD_GAME_NATIVE_DLL'='ON'
else ifeq ($(VM),exe)
    VM_TYPE := 2
    CMAKE_GAME_ARGS := \
        -D'BUILD_GAME_NACL'='OFF' \
        -D'BUILD_GAME_NACL_NEXE'='OFF' \
        -D'BUILD_GAME_NATIVE_EXE'='ON' \
        -D'BUILD_GAME_NATIVE_DLL'='OFF'
else ifeq ($(VM),nexe)
    VM_TYPE := 1
    CMAKE_GAME_ARGS := \
        -D'BUILD_GAME_NACL'='ON' \
        -D'BUILD_GAME_NACL_NEXE'='ON' \
        -D'BUILD_GAME_NACL_TARGETS'="$(NEXE)" \
        -D'BUILD_GAME_NATIVE_EXE'='OFF'\
        -D'BUILD_GAME_NATIVE_DLL'='OFF'
endif

ifeq ($(VM),nexe)
    GAME_COMPILER := nacl
    CMAKE_GAME_COMPILER_FLAGS := \
        -D'CMAKE_C_FLAGS'='' \
        -D'CMAKE_CXX_FLAGS'=''
    CMAKE_GAME_LINKER_FLAGS := \
        -D'CMAKE_EXE_LINKER_FLAGS'=''
else
    GAME_COMPILER := ${COMPILER}
    GAME_TOOLCHAIN := ${TOOLCHAIN}
    CMAKE_GAME_COMPILER_ARGS := $(CMAKE_COMPILER_ARGS)
    CMAKE_GAME_USELD_ARGS := $(CMAKE_USELD_ARGS)
    CMAKE_GAME_COMPILER_FLAGS := \
        -D'CMAKE_C_FLAGS'='${ARCH_FLAGS} ${NATIVE_C_COMPILER_FLAGS} ${COMPILER_FLAGS}' \
        -D'CMAKE_CXX_FLAGS'='${ARCH_FLAGS} ${NATIVE_CXX_COMPILER_FLAGS} ${COMPILER_FLAGS}'
    CMAKE_GAME_LINKER_FLAGS := \
        -D'CMAKE_EXE_LINKER_FLAGS'='${NATIVE_LINKER_FLAGS} ${LINKER_FLAGS}'
endif

ifneq ($(GAME_TOOLCHAIN),)
    GAME_TOOLCHAIN := daemon/${GAME_TOOLCHAIN}
endif

ENGINE_PREFIX := ${PREFIX}-${SYSTEM}-${COMPILER}-${LINK}-${BUILD_TYPE}-exe
GAME_PREFIX := ${PREFIX}-${SYSTEM}-${GAME_COMPILER}-${LINK}-${BUILD_TYPE}-${VM}

ENGINE_BUILD := ${BUILD_DIR}/engine/${ENGINE_PREFIX}
GAME_BUILD := ${BUILD_DIR}/game/${GAME_PREFIX}

DATA_BUILD_PREFIX := ${BUILD_DIR}/data
DATA_BUILD := ${DATA_BUILD_PREFIX}/${PAK_PREFIX}

ENGINE_VMTYPE_ARGS := -set vm.cgame.type ${VM_TYPE} -set vm.sgame.type ${VM_TYPE}

ifeq ($(LOG),Debug)
    ENGINE_LOG_ARGS := -set logs.suppression.enabled 0 -set logs.level.default debug -set logs.level.audio debug -set logs.level.glconfig debug -set developer 1
else
    ENGINE_LOG_ARGS := -set logs.suppression.enabled 1 -set logs.level.default notice -set logs.level.audio notice  -set logs.level.glconfig notice -set developer 0
endif

ifeq ($(DATA),ON)
else ifeq ($(DATA),OFF)
else ifeq ($(DATA),)
    DATA := ON
else
    $(error Bad DATA value: $(DATA))
endif

ifeq ($(DATA),ON)
    DPKDIR_PAKPATH_ARGS := -pakpath '${DATA_BUILD}'
endif

EXTRA_PAKPATH_ARGS := $(shell [ -f .pakpaths ] && ( grep -v '\#' .pakpaths | sed -e 's/^/-pakpath /' | tr '\n' ' '))

ifeq ($(RUNNER),wine)
    SYSTEM_DEPS := windows
else
    SYSTEM_DEPS := other
endif

ifneq ($(ARGS),)
    USER_ARGS := ${ARGS}
endif

ifneq ($(MAP),)
    USER_ARGS := ${USER_ARGS} +devmap ${MAP}
endif

clone-game:
	(! [ -d '${GAME_DIR}' ] && git clone '${GAME_REPO}' '${GAME_DIR}') || true

clone-assets:
	(! [ -d '${DATA_DIR}' ] && git clone '${DATA_REPO}' '${DATA_DIR}') || true
	cd '${DATA_DIR}' && git submodule update --init --recursive

clone-bin: clone-game

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

set-current-engine:
	mkdir -p build/engine
	${LN_CMD} --no-target-directory \
		'${ENGINE_PREFIX}' build/engine/current

configure-engine: set-current-engine
	${MOLD_CMD} '${CMAKE_BIN}' '${ENGINE_DIR}' -B'${ENGINE_BUILD}' \
		-G'${GEN}' \
		-D'CMAKE_TOOLCHAIN_FILE'='${TOOLCHAIN}' \
		${CMAKE_COMPILER_ARGS} \
		${CMAKE_USELD_ARGS} \
		${CMAKE_DEBUG_ARGS} \
		${CMAKE_ENGINE_COMPILER_FLAGS} \
		${CMAKE_ENGINE_LINKER_FLAGS} \
		${CMAKE_ARGS} \
		-D'USE_PRECOMPILED_HEADER'='${PCH}' \
		-D'USE_LTO'='${LTO}' \
		-D'USE_HARDENING'='${HARDENING}' \
		-D'USE_PEDANTIC'='${PEDANTIC}' \
		-D'USE_WERROR'='${WERROR}' \
		-D'EXTERNAL_DEPS_DIR'='${EXDEPS_DIR}' \
		-D'BUILD_SERVER'='ON' -D'BUILD_CLIENT'='ON' -D'BUILD_TTY_CLIENT'='ON' \
	|| ( rm -v '${ENGINE_BUILD}/CMakeCache.txt' ; false )

engine-runtime: configure-engine
	${MOLD_CMD} '${CMAKE_BIN}' --build '${ENGINE_BUILD}' -- -j'${NPROC}' runtime_deps

engine-server: configure-engine
	${MOLD_CMD} '${CMAKE_BIN}' --build '${ENGINE_BUILD}' -- -j'${NPROC}' server

engine-client: configure-engine
	${MOLD_CMD} '${CMAKE_BIN}' --build '${ENGINE_BUILD}' -- -j'${NPROC}' client

engine-tty: configure-engine
	${MOLD_CMD} '${CMAKE_BIN}' --build '${ENGINE_BUILD}' -- -j'${NPROC}' ttyclient

engine: configure-engine
	${MOLD_CMD} '${CMAKE_BIN}' --build '${ENGINE_BUILD}' -- -j'${NPROC}' server client ttyclient

engine-windows-extra:
	{ \
		for dll_name in libssp-0.dll libwinpthread-1.dll libgcc_s_seh-1.dll libstdc++-6.dll; \
		do \
			mingw_arch='x86_64-w64-mingw32'; \
			dll_location="$$(find '/usr' -name "$${dll_name}" -type f | sort | grep --max-count=1 "$${mingw_arch}")"; \
			cp -av "$${dll_location}" "${ENGINE_BUILD}/$${dll_name}"; \
		done; \
	}

engine-other-extra:

engine-extra: engine-${SYSTEM_DEPS}-extra

set-current-game:
	mkdir -p build/game
	${LN_CMD} --no-target-directory \
		'${GAME_PREFIX}' build/game/current

configure-game: configure-engine set-current-game
	${MOLD_CMD} '${CMAKE_BIN}' '${GAME_DIR}' -B'${GAME_BUILD}' \
		-G'${GEN}' \
		-D'CMAKE_TOOLCHAIN_FILE'='${GAME_TOOLCHAIN}' \
		${CMAKE_GAME_COMPILER_ARGS} \
		${CMAKE_GAME_USELD_ARGS} \
		${CMAKE_DEBUG_ARGS} \
		${CMAKE_GAME_ARGS} \
		${CMAKE_GAME_COMPILER_FLAGS} \
		${CMAKE_GAME_LINKER_FLAGS} \
		${CMAKE_ARGS} \
		-D'USE_PRECOMPILED_HEADER'='${PCH}' \
		-D'USE_LTO'='${LTO}' \
		-D'USE_HARDENING'='${HARDENING}' \
		-D'USE_PEDANTIC'='${PEDANTIC}' \
		-D'USE_WERROR'='${WERROR}' \
		-D'EXTERNAL_DEPS_DIR'='${EXDEPS_DIR}' \
		-D'BUILD_SERVER'='OFF' -D'BUILD_CLIENT'='OFF' -D'BUILD_TTY_CLIENT'='OFF' \
		-D'BUILD_SGAME'='ON' -D'BUILD_CGAME'='ON' \
		-D'DAEMON_DIR'='${ENGINE_DIR}' \
	|| ( rm -v '${GAME_BUILD}/CMakeCache.txt' ; false )

	echo '${VM_TYPE}' > '${GAME_BUILD}/vm_type.txt'

game: configure-game
	${MOLD_CMD} '${CMAKE_BIN}' --build '${GAME_BUILD}' -- -j'${NPROC}'

game-nexe-windows-extra:

game-nexe-other-extra: engine-runtime set-current-game
	${LN_CMD} ${ENGINE_BUILD}/nacl_helper_bootstrap ${GAME_BUILD}/nacl_helper_bootstrap

game-nexe-extra: game-nexe-${SYSTEM_DEPS}-extra engine-runtime set-current-game
	${LN_CMD} ${ENGINE_BUILD}/irt_core-amd64.nexe ${GAME_BUILD}/irt_core-amd64.nexe
	${LN_CMD} ${ENGINE_BUILD}/nacl_loader${EXE_EXT} ${GAME_BUILD}/nacl_loader${EXE_EXT}

game-exe-extra:

game-dll-extra:

game-extra: game-${VM}-extra

bin-extra: engine-extra game-extra

build-client: engine-client game
bin-client: build-client bin-extra
bin-client-nobuild:

build-server: engine-server game
bin-server: build-server bin-extra
bin-server-nobuild:

build-tty: engine-tty game
bin-tty: build-tty bin-extra
bin-tty-nobuild:

bin: engine game

set-current: set-current-engine set-current-game

prepare-base:
	urcheon -C '${GAME_DIR}' --build-prefix='${DATA_BUILD_PREFIX}' prepare pkg/unvanquished_src.dpkdir

build-base: prepare-base
	urcheon -C '${GAME_DIR}' --build-prefix='${DATA_BUILD_PREFIX}' build pkg/unvanquished_src.dpkdir

package-base: build-base
	urcheon -C '${GAME_DIR}' --build-prefix='${DATA_BUILD_PREFIX}' package pkg/unvanquished_src.dpkdir

base: ${DATA_ACTION}-base

prepare-maps:
	cd '${DATA_DIR}' && urcheon prepare pkg/map-*.dpkdir

build-maps: prepare-maps
	cd '${DATA_DIR}' && urcheon --build-prefix='${DATA_BUILD_PREFIX}' build pkg/map-*.dpkdir

package-maps: build-maps
	cd '${DATA_DIR}' && urcheon --build-prefix='${DATA_BUILD_PREFIX}' package pkg/map-*.dpkdir

maps: ${DATA_ACTION}-maps

prepare-resources:
	cd '${DATA_DIR}' && urcheon prepare pkg/res-*_src.dpkdir pkg/tex-*_src.dpkdir

build-resources: prepare-resources
	cd '${DATA_DIR}' && urcheon --build-prefix='${DATA_BUILD_PREFIX}' build pkg/res-*_src.dpkdir pkg/tex-*_src.dpkdir

package-resources: build-resources
	cd '${DATA_DIR}' && urcheon --build-prefix='${DATA_BUILD_PREFIX}' package pkg/res-*_src.dpkdir pkg/tex-*_src.dpkdir

resources: ${DATA_ACTION}-resources

prepare-data: prepare-base prepare-resources prepare-maps

build-data: build-base build-resources build-maps

package-data: package-base package-resources package-maps

data: ${DATA_ACTION}-data

build: bin data

clean-engine:
	${MOLD_CMD} '${CMAKE_BIN}' --build '${ENGINE_BUILD}' -- clean

clean-game:
	${MOLD_CMD} '${CMAKE_BIN}' --build '${GAME_BUILD}' -- clean

clean-bin: clean-engine clean-game

run-server: bin-server${NOBUILD_SUFFIX}
	LD_PRELOAD='${LD_RUNNER}' \
	${RUNNER} \
	'${ENGINE_BUILD}/daemonded${ENGINE_EXT}' \
		${ENGINE_LOG_ARGS} \
		${ENGINE_VMTYPE_ARGS} \
		-libpath '${GAME_BUILD}' \
		${DPKDIR_PAKPATH_ARGS} \
		${EXTRA_PAKPATH_ARGS} \
		${SERVER_ARGS} \
		${USER_ARGS}

run-client: bin-client${NOBUILD_SUFFIX}
	LD_PRELOAD='${LD_RUNNER}' \
	${RUNNER} \
	'${ENGINE_BUILD}/daemon${ENGINE_EXT}' \
		${ENGINE_LOG_ARGS} \
		${ENGINE_VMTYPE_ARGS} \
		-libpath '${GAME_BUILD}' \
		${DPKDIR_PAKPATH_ARGS} \
		${EXTRA_PAKPATH_ARGS} \
		${SERVER_ARGS} \
		${CLIENT_ARGS} \
		${USER_ARGS}

run-tty: bin-tty${NOBUILD_SUFFIX}
	LD_PRELOAD='${LD_RUNNER}' \
	${RUNNER} \
	'${ENGINE_BUILD}/daemon-tty${ENGINE_EXT}' \
		${ENGINE_LOG_ARGS} \
		${ENGINE_VMTYPE_ARGS} \
		-libpath '${GAME_BUILD}' \
		${DPKDIR_PAKPATH_ARGS} \
		${EXTRA_PAKPATH_ARGS} \
		${SERVER_ARGS} \
		${CLIENT_ARGS} \
		${USER_ARGS}

run: run-client

load_map:
	$(MAKE) run ARGS="${ARGS} +devmap plat23"

load_game:
	$(MAKE) load_map ARGS="${ARGS} +delay 3f bot fill 5"

it: build load_game
