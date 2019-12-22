FROM alpine:latest

# build perl
RUN apk add --no-cache gcc libc-dev curl perl patch make wget && \
    curl --compressed -sSL https://raw.githubusercontent.com/tokuhirom/Perl-Build/master/perl-build | perl - 5.8.8 /opt/perl-5.8/ && \
    # do not remove gcc and libc-dev because some cpan modules need them
    apk del perl patch

ENV PATH=/opt/perl-5.8/bin:$PATH
RUN curl --compressed -sSL https://cpanmin.us/ | perl - --notest App::FatPacker::Simple Carton ExtUtils::PL2Bat

RUN mkdir -p /tmp/carton
WORKDIR /tmp/carton

COPY cpanfile .
COPY build.pl .
COPY cpanfile.snapshot .

RUN carton install --deployment
