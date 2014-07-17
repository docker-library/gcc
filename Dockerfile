FROM buildpack-deps

RUN apt-get update && apt-get install -y flex wget

RUN mkdir -p /usr/src/gcc/objdir
ADD . /usr/src/gcc/srcdir

WORKDIR /usr/src/gcc/srcdir
RUN ./contrib/download_prerequisites

WORKDIR /usr/src/gcc/objdir
RUN ../srcdir/configure --disable-multilib --enable-languages=c,c++ \
	&& make -j$(nproc) \
	&& make install
