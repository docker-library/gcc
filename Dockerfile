FROM buildpack-deps

RUN apt-get update
RUN apt-get install -y wget && apt-get install -y flex

RUN mkdir /usr/src/gcc
RUN mkdir /usr/src/gcc/objdir
ADD . /usr/src/gcc/srcdir

WORKDIR /usr/src/gcc/srcdir
RUN /usr/src/gcc/srcdir/contrib/download_prerequisites

WORKDIR /usr/src/gcc/objdir
RUN /usr/src/gcc/srcdir/configure --disable-multilib --enable-languages=c,c++ && make -j$(($(nproc)-1)) && make install
