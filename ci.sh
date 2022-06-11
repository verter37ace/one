#!/usr/bin/env bash

IFS='|' read -r -a config_args <<< "${1:-}"
IFS='|' read -r -a build_args <<< "${2:-}"
IFS='|' read -r -a test_args <<< "${3:-}"
set -euxo pipefail

function default_test {
	GTEST_SHUFFLE=1 GTEST_RUNTIME_LIMIT=99 MALLOC_CHECK_=7 MALLOC_PERTURB_=42 \
	ctest --output-on-failure --parallel 2 --schedule-random --no-tests=error \
	"${test_args[@]+"${test_args[@]}"}"
}

function default_build {
	set +ex
	echo -n "CC: ${CC:=$((which cc || which gcc || which clang || which true) 2>/dev/null)} => " && "$CC" --version | head -1
	echo -n "CXX: ${CXX:=$((which c++ || which g++ || which clang++ || which true) 2>/dev/null)} => " && "$CXX" --version | head -1
	echo -n "CMAKE: ${CMAKE:=$((which cmake || which false) 2>/dev/null)} => " && "$CMAKE" --version | head -1
	mkdir @build && cd @build
	set -euxo pipefail
	cmake "${config_args[@]+"${config_args[@]}"}" ../subj && cmake --build . "${build_args[@]+"${build_args[@]}"}"
}

function default_ci {
	default_build && default_test && echo Done
}

git clean -x -f -d
if [ -f url ]; then
	git clone -q --single-branch --recurse-submodules -j 2 $(cat url) subj
else
	git submodule sync --recursive
	git submodule update --init --recursive
	#git submodule foreach --recursive 'git fetch $(test -f .git/shallow && echo --unshallow) --tags --prune --force'
	git submodule foreach --recursive git fetch --update-shallow --tags --prune --force
fi

if [ -x ./subj/test/ci.sh ]; then
	ci_script=subj/test/ci.sh
elif [ -x ./subj/ci.sh ]; then
	ci_script=subj/ci.sh
else
	ci_script=default_ci
fi

$ci_script
