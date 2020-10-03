FROM alpine:latest

# build perl
RUN apk add --no-cache gcc libc-dev curl perl patch make wget

RUN curl --compressed -sSL https://raw.githubusercontent.com/tokuhirom/Perl-Build/master/perl-build | perl - 5.32.0 /opt/perl-5.32/

# do not remove gcc and libc-dev because some cpan modules need them
RUN apk del perl patch

ENV PATH=/opt/perl-5.32/bin:$PATH
RUN curl --compressed -sSL https://cpanmin.us/ | perl - --notest App::FatPacker::Simple Carton ExtUtils::PL2Bat

RUN mkdir -p /tmp/cpm
WORKDIR /tmp/cpm

COPY cpanfile .
COPY build.pl .
COPY cpanfile.snapshot .

RUN carton install --deployment
