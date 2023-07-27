#
# NOTE: THIS DOCKERFILE IS GENERATED VIA "apply-templates.sh"
#
# PLEASE DO NOT EDIT IT DIRECTLY.
#

FROM buildpack-deps:bookworm

# https://gcc.gnu.org/mirrors.html
ENV GPG_KEYS \
# 1024D/745C015A 1999-11-09 Gerald Pfeifer <gerald@pfeifer.com>
	B215C1633BCA0477615F1B35A5B3A004745C015A \
# 1024D/B75C61B8 2003-04-10 Mark Mitchell <mark@codesourcery.com>
	B3C42148A44E6983B3E4CC0793FA9B1AB75C61B8 \
# 1024D/902C9419 2004-12-06 Gabriel Dos Reis <gdr@acm.org>
	90AA470469D3965A87A5DCB494D03953902C9419 \
# 1024D/F71EDF1C 2000-02-13 Joseph Samuel Myers <jsm@polyomino.org.uk>
	80F98B2E0DAB6C8281BDF541A7C8C3B2F71EDF1C \
# 2048R/FC26A641 2005-09-13 Richard Guenther <richard.guenther@gmail.com>
	7F74F97C103468EE5D750B583AB00996FC26A641 \
# 1024D/C3C45C06 2004-04-21 Jakub Jelinek <jakub@redhat.com>
	33C235A34C46AA3FFB293709A328C3A2C3C45C06 \
# 4096R/09B5FA62 2020-05-28 Jakub Jelinek <jakub@redhat.com>
	D3A93CAD751C2AF4F8C7AD516C35B99309B5FA62

RUN set -ex; \
	apt-get update; \
	apt-get install -y --no-install-recommends \
		gnupg \
	; \
	rm -rf /var/lib/apt/lists/*; \
	for key in $GPG_KEYS; do \
		gpg --batch --keyserver keyserver.ubuntu.com --recv-keys "$key"; \
	done

# https://gcc.gnu.org/mirrors.html
ENV GCC_MIRRORS \
		https://ftpmirror.gnu.org/gcc \
		https://mirrors.kernel.org/gnu/gcc \
		https://bigsearcher.com/mirrors/gcc/releases \
		http://www.netgull.com/gcc/releases \
		https://ftpmirror.gnu.org/gcc \
# only attempt the origin FTP as a mirror of last resort
		ftp://ftp.gnu.org/gnu/gcc

# Last Modified: 2023-07-27
ENV GCC_VERSION 13.2.0
# Docker EOL: 2025-01-27

RUN set -ex; \
	\
	savedAptMark="$(apt-mark showmanual)"; \
	apt-get update; \
	apt-get install -y --no-install-recommends \
		dpkg-dev \
		flex \
	; \
	rm -r /var/lib/apt/lists/*; \
	\
	_fetch() { \
		local fetch="$1"; shift; \
		local file="$1"; shift; \
		for mirror in $GCC_MIRRORS; do \
			if curl -fL "$mirror/$fetch" -o "$file"; then \
				return 0; \
			fi; \
		done; \
		echo >&2 "error: failed to download '$fetch' from several mirrors"; \
		return 1; \
	}; \
	\
	_fetch "gcc-$GCC_VERSION/gcc-$GCC_VERSION.tar.xz.sig" 'gcc.tar.xz.sig'; \
	_fetch "gcc-$GCC_VERSION/gcc-$GCC_VERSION.tar.xz" 'gcc.tar.xz'; \
	gpg --batch --verify gcc.tar.xz.sig gcc.tar.xz; \
	mkdir -p /usr/src/gcc; \
	tar -xf gcc.tar.xz -C /usr/src/gcc --strip-components=1; \
	rm gcc.tar.xz*; \
	\
	cd /usr/src/gcc; \
	\
# "download_prerequisites" pulls down a bunch of tarballs and extracts them,
# but then leaves the tarballs themselves lying around
	./contrib/download_prerequisites; \
	{ rm *.tar.* || true; }; \
	\
# explicitly update autoconf config.guess and config.sub so they support more arches/libcs
	for f in config.guess config.sub; do \
		wget -O "$f" "https://git.savannah.gnu.org/cgit/config.git/plain/$f?id=7d3d27baf8107b630586c962c057e22149653deb"; \
# find any more (shallow) copies of the file we grabbed and update them too
		find -mindepth 2 -name "$f" -exec cp -v "$f" '{}' ';'; \
	done; \
	\
	dir="$(mktemp -d)"; \
	cd "$dir"; \
	\
	extraConfigureArgs=''; \
	dpkgArch="$(dpkg --print-architecture)"; \
	case "$dpkgArch" in \
# with-arch: https://salsa.debian.org/toolchain-team/gcc/-/blob/gcc-11-debian/debian/rules2#L462-502
# with-float: https://salsa.debian.org/toolchain-team/gcc/-/blob/gcc-11-debian/debian/rules.defs#L502-512
# with-mode: https://salsa.debian.org/toolchain-team/gcc/-/blob/gcc-11-debian/debian/rules.defs#L480
		armel) \
			extraConfigureArgs="$extraConfigureArgs --with-arch=armv5te --with-float=soft" \
			;; \
		armhf) \
			# https://bugs.launchpad.net/ubuntu/+source/gcc-defaults/+bug/1939379/comments/2
			extraConfigureArgs="$extraConfigureArgs --with-arch=armv7-a+fp --with-float=hard --with-mode=thumb" \
			;; \
		\
# with-arch-32: https://salsa.debian.org/toolchain-team/gcc/-/blob/gcc-11-debian/debian/rules2#L598
		i386) \
			extraConfigureArgs="$extraConfigureArgs --with-arch-32=i686"; \
			;; \
	esac; \
	\
	gnuArch="$(dpkg-architecture --query DEB_BUILD_GNU_TYPE)"; \
	/usr/src/gcc/configure \
		--build="$gnuArch" \
		--disable-multilib \
		--enable-languages=c,c++,fortran,go \
		$extraConfigureArgs \
	; \
	make -j "$(nproc)"; \
	make install-strip; \
	\
	cd ..; \
	\
	rm -rf "$dir" /usr/src/gcc; \
	\
	apt-mark auto '.*' > /dev/null; \
	[ -z "$savedAptMark" ] || apt-mark manual $savedAptMark; \
	apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false

# gcc installs .so files in /usr/local/lib64 (and /usr/local/lib)...
RUN set -ex; \
# this filename needs to sort higher than all the architecture filenames ("aarch64-...", "armeabi...", etc)
	{ echo '/usr/local/lib64'; echo '/usr/local/lib'; } > /etc/ld.so.conf.d/000-local-lib.conf; \
	ldconfig -v; \
	# the libc created by gcc might be too old for a newer Debian
	# check that the Debian libstdc++ doesn't have newer requirements than the gcc one
	bash -Eeuo pipefail -xc ' \
		deb="$(strings /usr/lib/*/libstdc++.so* | grep "^GLIBC" | sort -u)"; \
		gcc="$(strings /usr/local/lib*/libstdc++.so | grep "^GLIBC" | sort -u)"; \
		diff="$(comm -23 <(cat <<<"$deb") <(cat <<<"$gcc"))"; \
		test -z "$diff"; \
	'

# ensure that alternatives are pointing to the new compiler and that old one is no longer used
RUN set -ex; \
	dpkg-divert --divert /usr/bin/gcc.orig --rename /usr/bin/gcc; \
	dpkg-divert --divert /usr/bin/g++.orig --rename /usr/bin/g++; \
	dpkg-divert --divert /usr/bin/gfortran.orig --rename /usr/bin/gfortran; \
	update-alternatives --install /usr/bin/cc cc /usr/local/bin/gcc 999
