# Dockerfile for fatpacking environment

FROM alpine:3.18.0

# build perl
RUN apk add --no-cache gcc libc-dev curl perl patch make wget

RUN curl --compressed -sSL https://raw.githubusercontent.com/tokuhirom/Perl-Build/master/perl-build | perl - 5.8.8 /opt/perl-5.8/

# do not remove gcc and libc-dev because some cpan modules need them
RUN apk del perl

ENV PATH=/opt/perl-5.8/bin:$PATH
RUN curl --compressed -sSL https://cpanmin.us/ | perl - --notest Carton

RUN mkdir -p /tmp/cpanm
WORKDIR /tmp/cpanm
