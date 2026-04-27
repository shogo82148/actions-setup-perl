FROM alpine:3.22.4

# build perl
RUN apk add --no-cache gcc libc-dev curl perl patch make wget

RUN curl --compressed -sSL https://raw.githubusercontent.com/tokuhirom/Perl-Build/master/perl-build | perl - 5.24.4 /opt/perl-5.24/

# do not remove gcc and libc-dev because some cpan modules need them
RUN apk del perl patch

ENV PATH=/opt/perl-5.24/bin:$PATH
RUN curl --compressed -sSL https://cpanmin.us/ | perl - --notest Carton ExtUtils::PL2Bat

RUN mkdir -p /tmp/cpm
WORKDIR /tmp/cpm
