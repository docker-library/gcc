#!/bin/bash
set -Eeuo pipefail

defaultDebianSuite='stretch'
declare -A debianSuites=(
	[6]='jessie'
	[5]='jessie'
)

cd "$(dirname "$(readlink -f "$BASH_SOURCE")")"

versions=( "$@" )
if [ ${#versions[@]} -eq 0 ]; then
	versions=( */ )
fi
versions=( "${versions[@]%/}" )

#packagesUrl='https://ftpmirror.gnu.org/gcc/'
packagesUrl='https://mirrors.kernel.org/gnu/gcc/' # the actual HTML of the page changes based on which mirror we end up hitting, so let's hit a specific one for now... :'(
packages="$(echo "$packagesUrl" | sed -r 's/[^a-zA-Z.-]+/-/g')"
curl -fsSL "$packagesUrl" > "$packages"

# our own "supported" window is 1 year from the most recent release because upstream doesn't have a good guideline, but appears to only release maintenance updates for 2-3 years after the initial release
# in addition, maintenance releases are _usually_ less than a year apart; from 4.7+ there's only one outlier, and it's 4.7.3->4.7.4 at ~14 months
export TZ=UTC
eolPeriod='1 year'
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

	debianSuite="${debianSuites[$version]:-$defaultDebianSuite}"

	compression=
	for tryCompression in xz bz2 gz; do
		if wget --quiet --spider "$packagesUrl/gcc-$fullVersion/gcc-$fullVersion.tar.$tryCompression"; then
			compression="$tryCompression"
			break
		fi
	done
	if [ -z "$compression" ]; then
		echo >&2 "error: $fullVersion does not seem to even really exist"
		exit 1
	fi

	(
		set -x
		sed -r \
			-e 's!%%SUITE%%!'"$debianSuite"'!g' \
			-e 's!^(ENV GCC_VERSION) .*!\1 '"$fullVersion"'!' \
			-e 's!^(# Last Modified:) .*!\1 '"$lastModified"'!' \
			-e 's!^(# Docker EOL:) .*!\1 '"$eolDate"'!' \
			-e 's!%%TARBALL-COMPRESSION%%!'"$compression"'!g' \
			Dockerfile.template \
			> "$version/Dockerfile"
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
