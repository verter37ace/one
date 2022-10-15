#!/usr/bin/env bash

function failure() {
	echo "Oops, $* failed ;(" >&2
	exit 2
}

export ci_script_recursion="$((++ci_script_recursion))"
if [ $ci_script_recursion -gt 3 ]; then
     failure "WTF: ci_script_recursion = $ci_script_recursion ?"
fi

IFS='|' read -r -a config_args <<< "${1:-}"
IFS='|' read -r -a build_args <<< "${2:-}"
IFS='|' read -r -a test_args <<< "${3:-}"
set -euxo pipefail

function provide_toolchain {
	set +ex
	echo "CC: ${CC:=$((which cc || which gcc || which clang || which true) 2>/dev/null)} => $($CC --version | head -1)"
	echo "CXX: ${CXX:=$((which c++ || which g++ || which clang++ || which true) 2>/dev/null)} => $($CXX --version | head -1)"
	if [ -z "$(which cmake 2>/dev/null)" -o -z "$(which ninja 2>/dev/null)" ]; then
		if [ -n "$(which apt 2>/dev/null)" ]; then
			apt update && apt install -y cmake ninja-build
		elif [ -n "$(which dnf 2>/dev/null)" ]; then
			dnf install -y cmake ninja-build
		elif [ -n "$(which yum 2>/dev/null)" ]; then
			yum install -y cmake ninja-build
		fi
	fi
	CMAKE_VERSION=$(eval expr $(cmake --version | sed -n 's/cmake version \([0-9]\{1,\}\)\.\([0-9]\{1,\}\)\.\([0-9]\{1,\}\)/\10000 + \200 + \3/p'))
	echo "CMAKE: $(which cmake 2>/dev/null) => $(cmake --version | head -1) ($CMAKE_VERSION)"
	set -euxo pipefail
}

function default_test {
	GTEST_SHUFFLE=1 GTEST_RUNTIME_LIMIT=99 MALLOC_CHECK_=7 MALLOC_PERTURB_=42 \
	ctest --output-on-failure --parallel 3 --schedule-random --no-tests=error \
	"${test_args[@]+"${test_args[@]}"}"
}

function default_build {
	local cmake_use_ninja=""
	if cmake --help | grep -iq ninja && [ -n "$(which ninja 2>/dev/null)" ] && echo " ${config_args[@]+"${config_args[@]}"}" | grep -qv -e ' -[GTA] '; then
		echo "NINJA: $(which ninja 2>/dev/null) => $(ninja --version | head -1)"
		cmake_use_ninja="-G Ninja"
	fi
	cmake ${cmake_use_ninja} "${config_args[@]+"${config_args[@]}"}" .. && cmake --build . "${build_args[@]+"${build_args[@]}"}"
}

function default_ci {
	provide_toolchain
	if [ -e CMakeLists.txt -a $CMAKE_VERSION -ge 30802 ]; then
		mkdir @build && cd @build && default_build && default_test && echo "Done (cmake)"
	elif [ -e GNUmakefile -o -e Makefile -o -e makefile ]; then
		make -j2 all && make test && echo "Done (make)"
	else
		echo "Skipped since CMAKE_VERSION ($CMAKE_VERSION) < 3.8.2 and no Makefile"
	fi
}

git clean -x -f -d || echo "ignore 'git clean' error"
git config --global submodule.fetchJobs 2

if [ -f url ]; then
	git clone -q --single-branch --recurse-submodules $(cat url) subj && cd subj || failure git-clone
else
	git submodule sync --recursive || failure git-submodule-sync
	git submodule update --init --recursive || failure git-submodule-update
	#git submodule foreach --recursive 'git fetch $(test -f .git/shallow && echo --unshallow) --tags --prune --force' || failure git-submodule-fetch
	git submodule foreach --recursive git fetch --update-shallow --tags --prune --force || failure git-submodule-fetch
fi

git describe --tags || git show --oneline -s

if [ -x test/ci.sh ]; then
	ci_script=./test/ci.sh
elif [ -x ci.sh ]; then
	ci_script=./ci.sh
else
	ci_script=default_ci
fi

$ci_script || failure $ci_script
