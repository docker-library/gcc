#!/usr/bin/env bash
set -Eeuo pipefail

# the libc created by gcc might be too old for a newer Debian:
# https://packages.debian.org/stable/gcc
# bookworm: 12.2
# bullseye: 10.2

# defaultDebianSuite gets auto-declared below
declare -A debianSuites=(
	['12']='bookworm'
	['13']='bookworm'
)

cd "$(dirname "$(readlink -f "$BASH_SOURCE")")"

versions=( "$@" )
if [ ${#versions[@]} -eq 0 ]; then
	versions=( */ )
	json='{}'
else
	json="$(< versions.json)"
fi
versions=( "${versions[@]%/}" )

debianStable="$(wget -qO- 'http://deb.debian.org/debian/dists/stable/Release' | grep -F 'Codename:')"
debianStable="$(awk <<<"$debianStable" '$1 == "Codename:" { print $2; exit }')"
[ -n "$debianStable" ]
defaultDebianSuite="$debianStable"

packagesUrl='https://sourceware.org/pub/gcc/releases/?C=M;O=D' # the actual HTML of the page changes based on which mirror we end up hitting, *and* sometimes specific mirrors are missing versions, so let's hit the original canonical host for version scraping
packages="$(wget -qO- "$packagesUrl")"

# our own "supported" window is 18 months from the most recent release because upstream doesn't have a good guideline, but appears to only release maintenance updates for 2-3 years after the initial release
# in addition, maintenance releases are _usually_ less than a year apart; from 4.7+ there's a handful of outliers, like 4.7.3->4.7.4 at ~14 months, 6.4->6.5 at ~15 months, etc
export TZ=UTC
eolPeriod='18 months'
today="$(date +'%s')"
eolAgo="$(date +'%s' -d "$(date -d "@$today") - $eolPeriod")"
eolAge="$(( $today - $eolAgo ))"
eols=()

dateFormat='%Y-%m-%d'

for version in "${versions[@]}"; do
	fullVersion="$(grep -P '<a href="(gcc-)?\Q'"$version."'\E' <<<"$packages" | sed -r 's!.*<a href="(gcc-)?([^"/]+)/?".*!\2!' | sort -V | tail -1)"
	lastModified="$(grep -Pm1 '<a href="(gcc-)?\Q'"$fullVersion"'\E/"' <<<"$packages" | grep -oPm1 '(?<![0-9])[0-9]{4}-[0-9]{2}-[0-9]{2}(?![0-9])')"
	lastModified="$(date -d "$lastModified" +"$dateFormat")"

	lastModifiedTime="$(date +'%s' -d "$lastModified")"
	releaseAge="$(( today - lastModifiedTime ))"
	if [ "$releaseAge" -gt "$eolAge" ]; then
		eols+=( "$version ($fullVersion)" )
	fi
	eolDate="$(date -d "$lastModified + $eolPeriod" +"$dateFormat")"

	debianSuite="${debianSuites[$version]:-$defaultDebianSuite}"

	compression=
	for tryCompression in xz bz2 gz; do
		if \
			wget --quiet --spider "$packagesUrl/gcc-$fullVersion/gcc-$fullVersion.tar.$tryCompression" \
			|| wget --quiet --spider "$packagesUrl/$fullVersion/gcc-$fullVersion.tar.$tryCompression" \
		; then
			compression="$tryCompression"
			break
		fi
	done
	if [ -z "$compression" ]; then
		echo >&2 "error: $fullVersion does not seem to even really exist"
		exit 1
	fi

	echo "$version: $fullVersion ($lastModified vs $eolDate); $debianSuite, $compression"

	export version fullVersion lastModified eolDate debianSuite compression
	json="$(jq <<<"$json" -c '
		.[env.version] = {
			version: env.fullVersion,
			lastModified: env.lastModified,
			eol: env.eolDate,
			compression: env.compression,
			debian: {
				version: env.debianSuite,
			},
		}
	')"
done

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

jq <<<"$json" -S . > versions.json
