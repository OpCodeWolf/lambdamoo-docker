# Arguments can be overridden with --build-arg or from docker-compose as an 'args:' parameter
ARG ALPINE_VERSION=latest
ARG USERNAME=moo
ARG USERGROUP=moogroup
ARG USERHOME=/home/${USERNAME}
ARG APPHOME=${USERHOME}/lambdamoo
ARG APPPORT=7777

###
# Alpine Base Image
#
FROM alpine:${ALPINE_VERSION} AS lambdamoo-base
# Import ARGs to this layer
ARG USERNAME
ARG USERGROUP
ARG USERHOME
ARG APPHOME
# Setup environment
SHELL ["/bin/sh", "-c"]
ENV APPHOME ${APPHOME}
ENV USERNAME ${USERNAME}
ENV USERHOME ${USERHOME}
ENV USERGROUP ${USERGROUP}

###
# Setup Users and Groups in root context
#
FROM lambdamoo-base AS lambdamoo-requirements
USER root
RUN addgroup -S $USERGROUP
RUN adduser --disabled-password -g "LambdaMOO User" --gecos "" --home $USERHOME --ingroup $USERGROUP $USERNAME
# Nginx (?) TODO: Future
# RUN addgroup -S www
# RUN adduser --disabled-password -g "Nginx www user" --gecos "" --home /home/www/ --ingroup www wwwmoo

###
# Install dependency requirements
#
RUN apk update && apk add \
    # Dependencies
    sudo nettle libcurl aspell-libs openssl-libs-static sqlite-libs argon2-libs pcre \
    # nginx ?
    # Development dependencies (required only for compilation)
    git alpine-sdk bison gperf g++ cmake sqlite-dev \
    aspell-dev pcre-dev nettle-dev curl-dev argon2-dev \
    openssl-dev

###
# Download the source
#
FROM lambdamoo-requirements AS lambdamoo-source
ARG USERNAME
ARG USERHOME
# Change to User context
USER $USERNAME
WORKDIR $USERHOME
# Clone Repositories
RUN git clone https://github.com/lisdude/toaststunt.git toaststunt
# RUN git clone https://github.com/lisdude/toastcore.git toastcore

###
# Compile the source
#
FROM lambdamoo-source AS lambdamoo-build
ARG USERHOME
ARG APPHOME
WORKDIR ${USERHOME}
RUN mkdir lambdamoo
WORKDIR ${USERHOME}/toaststunt
RUN mkdir build && cd build
RUN cmake -D CMAKE_BUILD_TYPE:STRING=Release .
RUN make -j2
# By default the output is an exececutable named moo
RUN chmod +x moo
WORKDIR ${APPHOME}
# Change the executable name to the desierd application name
RUN cp $USERHOME/toaststunt/moo moo
# RUN cp $USERHOME/toaststunt/restart.sh start.sh
# RUN cp $USERHOME/toastcore/toastcore.db moo.db

###
# Cleanup development dependencies
#
FROM lambdamoo-build AS lambdamoo-cleanup
ARG USERHOME
USER root
WORKDIR ${USERHOME}
RUN rm -rf toaststunt && rm -rf toastcore
# Delete unneeded development dependencies
RUN apk del \
    git alpine-sdk bison gperf cmake sqlite-dev aspell-dev \
    pcre-dev nettle-dev g++ curl-dev argon2-dev openssl-dev

###
# LambdaMoo Core
#
FROM lambdamoo-cleanup AS lambdamoo-core
ARG USERNAME
ARG APPHOME
ARG APPPORT
USER ${USERNAME}
WORKDIR ${APPHOME}
ENTRYPOINT ./start.sh moo ${APPPORT} && tail -f moo.log 
