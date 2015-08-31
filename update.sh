#!/bin/bash
set -e

cd "$(dirname "$(readlink -f "$BASH_SOURCE")")"

versions=( "$@" )
if [ ${#versions[@]} -eq 0 ]; then
	versions=( */ )
fi
versions=( "${versions[@]%/}" )

#packagesUrl='http://ftpmirror.gnu.org/gcc/'
packagesUrl='https://mirrors.kernel.org/gnu/gcc/' # the actual HTML of the page changes based on which mirror we end up hitting, so let's hit a specific one for now... :'(
packages="$(echo "$packagesUrl" | sed -r 's/[^a-zA-Z.-]+/-/g')"
curl -fsSL "$packagesUrl" > "$packages"

# our own "supported" window is 2 years because upstream doesn't have a good guideline, but appears to only release maintenance updates for 2-3 years
export TZ=UTC
eolPeriod='2 years'
today="$(date +'%s')"
eolAgo="$(date +'%s' -d "$(date -d "@$today") - $eolPeriod")"
eolAge="$(( $today - $eolAgo ))"
eols=()

dateFormat='%Y-%m-%d'

travisEnv=
for version in "${versions[@]}"; do
	travisEnv='\n  - VERSION='"$version$travisEnv"
	
	fullVersion="$(grep '<a href="gcc-'"$version." "$packages" | sed -r 's!.*<a href="gcc-([^"/]+)/?".*!\1!' | sort -V | tail -1)"
	lastModified="$(grep -m1 '<a href="gcc-'"$fullVersion"'/"' "$packages" | awk -F '  +' '{ print $2 }')"
	lastModified="$(date -d "$lastModified" +"$dateFormat")"
	
	releaseAge="$(( $today - $(date +'%s' -d "$lastModified") ))"
	if [ $releaseAge -gt $eolAge ]; then
		eols+=( "$version ($fullVersion)" )
	fi
	eolDate="$(date -d "$lastModified + $eolPeriod" +"$dateFormat")"
	
	(
		set -x
		sed -ri '
			s/^(ENV GCC_VERSION) .*/\1 '"$fullVersion"'/;
			s/^(# Last Modified:) .*/\1 '"$lastModified"'/;
			s/^(# Docker EOL:) .*/\1 '"$eolDate"'/;
		' "$version/Dockerfile"
	)
done

travis="$(awk -v 'RS=\n\n' '$1 == "env:" { $0 = "env:'"$travisEnv"'" } { printf "%s%s", $0, RS }' .travis.yml)"
echo "$travis" > .travis.yml

if [ ${#eols[@]} -gt 0 ]; then
	{
		echo
		echo
		echo
		echo " WARNING: the following releases are older than $eolPeriod:"
		echo
		for eol in "${eols[@]}"; do
			echo "   - $eol"
		done
		echo
		echo
		echo
	} >&2
fi

rm "$packages"
