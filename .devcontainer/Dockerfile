FROM public.ecr.aws/lts/ubuntu:22.04_stable

ARG DEBIAN_FRONTEND=noninteractive
ARG KEYRING_PATH=/usr/share/keyrings
ARG APT_SOURCES_PATH=/etc/apt/sources.list.d

# update and upgrade
RUN apt update && apt upgrade -y

# install essentialls
RUN apt update && \
  apt install -y \
  man make build-essential git zsh vim curl wget procps gnupg gnupg2 ca-certificates zip \
  software-properties-common

# unminimize the system
RUN bash -c "yes | unminimize"

# create dev sudo user
RUN useradd --create-home dev && \
  usermod --append --groups sudo dev && \
  apt update && apt install -y sudo && \
  echo '%sudo ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers

# install dumb init system
USER root
RUN apt update && apt install -y dumb-init

# setup oh-my-zsh
USER dev
ARG DOCKER_OHMYZSH_SCRIPT_NAME=zsh-in-docker.sh
ARG DOCKER_OHMYZSH_SCRIPT_URL=https://github.com/deluan/zsh-in-docker/releases/download/v1.1.3/${DOCKER_OHMYZSH_SCRIPT_NAME}
ARG DOCKER_OHMYZSH_SCRIPT_HASH="ffa8175332ef01b500ace59d03ce7e2f3a7453651e9a37060974bb6536f0706b  ${DOCKER_OHMYZSH_SCRIPT_NAME}"
RUN cd /tmp && \
  wget ${DOCKER_OHMYZSH_SCRIPT_URL} && \
  echo ${DOCKER_OHMYZSH_SCRIPT_HASH} | sha256sum -c && \
  chmod +x ./${DOCKER_OHMYZSH_SCRIPT_NAME} && \
  ./${DOCKER_OHMYZSH_SCRIPT_NAME} -t robbyrussell -p git -p ssh-agent && \
  rm ./${DOCKER_OHMYZSH_SCRIPT_NAME}

# build and install icarus verilog
USER dev
ARG MODELSIM_INSTALLER_URL=https://download.altera.com/akdlm/software/acdsinst/20.1std.1/720/ib_installers/${MODELSIM_INSTALLER_NAME}
ARG ICARUS_SRC_TAR=v12_0.tar.gz
ARG ICARUS_SRC_URL=https://github.com/steveicarus/iverilog/archive/refs/tags/${ICARUS_SRC_TAR}
ARG ICARUS_SRC_HASH="a68cb1ef7c017ef090ebedb2bc3e39ef90ecc70a3400afb4aa94303bc3beaa7d  ${ICARUS_SRC_TAR}"
RUN sudo apt update && sudo apt install -y autoconf gperf make gcc g++ bison flex && \
    cd /tmp && \
    wget ${ICARUS_SRC_URL} && \
    echo ${ICARUS_SRC_HASH} | sha256sum -c && \
    tar -xzf ${ICARUS_SRC_TAR} && \
    cd iverilog-* && sh autoconf.sh && ./configure && make && make check && sudo make install && \
    cd .. && rm ${ICARUS_SRC_TAR} && rm -rf ./iverilog-*

# install cocotb
USER dev
RUN sudo apt install -y python3 python3-pip libpython3-dev && \
  pip3 install cocotb~=1.9

ENTRYPOINT ["/usr/bin/dumb-init", "--"]
