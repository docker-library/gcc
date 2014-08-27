#!/bin/bash
set -e

cd "$(dirname "$(readlink -f "$BASH_SOURCE")")"

versions=( "$@" )
if [ ${#versions[@]} -eq 0 ]; then
	versions=( */ )
fi
versions=( "${versions[@]%/}" )

packagesUrl="http://ftpmirror.gnu.org/gcc/"
packages="$(echo "$packagesUrl" | sed -r 's/[^a-zA-Z.-]+/-/g')"
curl -sSL "$packagesUrl" > "$packages"

for version in "${versions[@]}"; do
	fullVersion="$(grep '<a href="gcc-'"$version." "$packages" | sed -r 's!.*<a href="gcc-([^"/]+)/?".*!\1!' | sort -V | tail -1)"
	
	(
		set -x
		sed -ri 's/^(ENV GCC_VERSION) .*/\1 '"$fullVersion"'/;' "$version/Dockerfile"
	)
done

rm "$packages"
