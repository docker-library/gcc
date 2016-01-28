FROM alpine:3.3
ENV GCC_VERSION 4.9.2-r5
RUN apk add --update-cache gcc=$GCC_VERSION libc-dev \
  && rm -rf /var/cache/apk/*

