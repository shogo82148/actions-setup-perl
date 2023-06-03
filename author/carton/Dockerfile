FROM alpine:latest

# build perl
RUN apk add --no-cache gcc libc-dev curl perl patch make wget

RUN curl --compressed -sSL https://raw.githubusercontent.com/tokuhirom/Perl-Build/master/perl-build | perl - 5.8.8 /opt/perl-5.8/

# do not remove gcc and libc-dev because some cpan modules need them
RUN apk del perl patch

ENV PATH=/opt/perl-5.8/bin:$PATH
RUN curl --compressed -sSL https://cpanmin.us/ | perl - --notest Distribution::Metadata@0.06 App::FatPacker::Simple@0.09 Carton ExtUtils::PL2Bat

RUN mkdir -p /tmp/carton
WORKDIR /tmp/carton

COPY cpanfile .
COPY build.pl .
COPY cpanfile.snapshot .

RUN carton install --deployment
