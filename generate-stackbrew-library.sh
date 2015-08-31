#!/bin/bash
set -e

declare -A aliases
aliases=(
	[4.9]='4'
	[5.2]='5 latest'
)

cd "$(dirname "$(readlink -f "$BASH_SOURCE")")"

versions=( */ )
versions=( "${versions[@]%/}" )
url='git://github.com/docker-library/gcc'

echo '# maintainer: InfoSiftr <github@infosiftr.com> (@infosiftr)'

for version in "${versions[@]}"; do
	commit="$(cd "$version" && git log -1 --format='format:%H' -- Dockerfile $(awk 'toupper($1) == "COPY" { for (i = 2; i < NF; i++) { print $i } }' Dockerfile))"
	fullVersion="$(grep -m1 'ENV GCC_VERSION ' "$version/Dockerfile" | cut -d' ' -f3 | cut -d- -f1 | sed 's/~/-/g')"
	versionAliases=( $fullVersion $version ${aliases[$version]} )
	
	echo
	grep -m1 '^# Last Modified: ' "$version/Dockerfile"
	for va in "${versionAliases[@]}"; do
		echo "$va: ${url}@${commit} $version"
	done
	grep -m1 '^# Docker EOL: ' "$version/Dockerfile"
done
