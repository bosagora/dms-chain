#!/bin/bash

set -eu

function color() {
    # Usage: color "31;5" "string"
    # Some valid values for color:
    # - 5 blink, 1 strong, 4 underlined
    # - fg: 31 red,  32 green, 33 yellow, 34 blue, 35 purple, 36 cyan, 37 white
    # - bg: 40 black, 41 red, 44 blue, 45 purple
    printf '\033[%sm%s\033[0m\n' "$@"
}

if [ "$#" -lt 1 ]; then
    color "31" "Usage: ./agora.sh PROCESS FLAGS."
    color "31" "PROCESS can be init"
    exit 1
fi

system=""
case "$OSTYPE" in
darwin*) system="darwin" ;;
linux*) system="linux" ;;
msys*) system="windows" ;;
cygwin*) system="windows" ;;
*) exit 1 ;;
esac
readonly system

architecture=""
case $(uname -m) in
    i386)    architecture="amd64" ;;
    i686)    architecture="amd64" ;;
    x86_64)  architecture="amd64" ;;
    aarch64) architecture="amd64" ;;
    arm)     architecture="arm64" ;;
esac

dirname=${PWD##*/}
agora_root="$(pwd)/agora"
if [ "$dirname" = "agora" ]; then
  agora_root="$(pwd)"
fi

if [ "$1" = "clear" ]; then

    if [ "$system" == "linux" ]; then
        sudo rm -rf "$agora_root"/chain
    else
        rm -rf "$agora_root"/chain
    fi

    mkdir -p "$agora_root"/chain

    mkdir -p "$agora_root"/chain/node1
    mkdir -p "$agora_root"/chain/node1/el

    cp -rf "$agora_root"/config/el/template/node1/* "$agora_root"/chain/node1/el

    docker run -it -v "$agora_root"/chain/node1/el:/data -v "$agora_root"/config/el:/config --name el-node --rm bosagora/agora-el-node:v1.0.2 --datadir=/data init /config/genesis.json

elif [ "$1" = "init" ]; then

    if [ "$system" == "linux" ]; then
        sudo rm -rf "$agora_root"/chain
    else
        rm -rf "$agora_root"/chain
    fi

    unzip -q "$agora_root"/chain.zip -d "$agora_root"

elif [ "$1" = "start" ]; then

    docker-compose -f "$agora_root"/nodes/docker-compose.yml up -d

elif [ "$1" = "stop" ]; then

  docker-compose -f "$agora_root"/nodes/docker-compose.yml down

elif [ "$1" = "attach" ]; then

    docker run -it -v "$agora_root"/chain/node1/el:/data -v "$agora_root"/config/el:/config --name el-node-attach --rm bosagora/agora-el-node:v1.0.2 --datadir=/data attach /data/geth.ipc

elif [ "$1" = "start-db" ]; then

    docker-compose -f "$agora_root"/postgres/docker-compose.yml up -d

elif [ "$1" = "stop-db" ]; then

    docker-compose -f "$agora_root"/postgres/docker-compose.yml down

    docker volume rm postgres_postgres-db

elif [ "$1" = "start-boa-scan" ]; then

    if [ "$architecture" == "amd64" ]; then
        docker-compose -f "$agora_root"/boa-scan/docker-compose-amd64.yml up -d
    else
        docker-compose -f "$agora_root"/boa-scan/docker-compose-arm64.yml up -d
    fi

elif [ "$1" = "stop-boa-scan" ]; then

    if [ "$architecture" == "amd64" ]; then
        docker-compose -f "$agora_root"/boa-scan/docker-compose-amd64.yml down
    else
        docker-compose -f "$agora_root"/boa-scan/docker-compose-arm64.yml down
    fi

else

    color "31" "Process '$1' is not found!"
    color "31" "Usage: ./agora.sh PROCESS FLAGS."
    color "31" "PROCESS can be init"
    exit 1

fi
