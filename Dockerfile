FROM buildpack-deps

RUN apt-get update && apt-get install -y flex wget

ADD . /usr/src/gcc

WORKDIR /usr/src/gcc
RUN ./contrib/download_prerequisites \
	&& rm *.tar.*
# "download_prerequisites" pulls down a bunch of tarballs and extracts them,
# but then leaves the tarballs themselves lying around

RUN dir="$(mktemp -d)" \
	&& cd "$dir" \
	&& /usr/src/gcc/configure \
		--disable-multilib \
		--enable-languages=c,c++ \
	&& make -j$(nproc) \
	&& make install-strip \
	&& cd .. \
	&& rm -rf "$dir"

# make sure our new gcc is definitely the one that gets used
RUN apt-get purge -y gcc g++ && apt-get autoremove -y
