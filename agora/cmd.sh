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

elif [ "$1" = "init-db" ]; then

  chmod 0600 "$agora_root"/postgres/.pgpass
  docker run -it --rm --net=host -v "$agora_root"/postgres:/src -v "$agora_root"/postgres/.pgpass:/root/.pgpass postgres:12.0 psql -f /src/init.sql -d postgres -h 0.0.0.0 -U agora > /dev/null

elif [ "$1" = "stop-db" ]; then

  docker-compose -f "$agora_root"/postgres/docker-compose.yml down

  docker volume rm postgres_postgres_db

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

  docker volume rm boa-scan_redis_db

elif [ "$1" = "start-faker" ]; then

  docker-compose -f "$agora_root"/faker/docker-compose.yml up -d

elif [ "$1" = "stop-faker" ]; then

  docker-compose -f "$agora_root"/faker/docker-compose.yml down

elif [ "$1" = "start-ipfs" ]; then

  export CLUSTER_SECRET=$(od -vN 32 -An -tx1 /dev/urandom | tr -d ' \n')
  echo $CLUSTER_SECRET

  docker-compose -f "$agora_root"/ipfs-private/docker-compose.yml up -d

elif [ "$1" = "stop-ipfs" ]; then

  docker-compose -f "$agora_root"/ipfs-private/docker-compose.yml down

  docker volume rm ipfs-private_node0_ipfs
  docker volume rm ipfs-private_node0_ipfs_cluster
  docker volume rm ipfs-private_node1_ipfs
  docker volume rm ipfs-private_node1_ipfs_cluster
  docker volume rm ipfs-private_node2_ipfs
  docker volume rm ipfs-private_node2_ipfs_cluster

elif [ "$1" = "start-graph" ]; then

  docker-compose -f "$agora_root"/graph/docker-compose.yml up -d

elif [ "$1" = "stop-graph" ]; then

  docker-compose -f "$agora_root"/graph/docker-compose.yml down

elif [ "$1" = "create-network" ]; then

  docker network create --subnet=172.200.0.0/16 bosagora_network

elif [ "$1" = "remove-network" ]; then

  docker network rm bosagora_network

elif [ "$1" = "deploy-subgraph" ]; then

  CURRENT_POS="$(pwd)"

  dirname2=${PWD##*/}
  if [ "$dirname2" = "agora" ]; then
    cd ../submodules/del-osx
  else
    cd submodules/del-osx
  fi

  yarn install

  cd packages/subgraph
  yarn run build:contracts
  yarn run manifest
  yarn run build
  yarn run create:devnet

  npx graph deploy bosagora/del-osx-devnet --node http://localhost:8020 --ipfs http://localhost:5001  --version-label v0.0.1

  cd "$CURRENT_POS"

  dirname2=${PWD##*/}
  if [ "$dirname2" = "agora" ]; then
    cd ../submodules/dms-osx
  else
    cd submodules/dms-osx
  fi

  yarn install

  cd packages/subgraph
  yarn run build:contracts
  yarn run manifest
  yarn run build
  yarn run create:devnet

  npx graph deploy bosagora/dms-osx-devnet --node http://localhost:8020 --ipfs http://localhost:5001  --version-label v0.0.1

  cd "$CURRENT_POS"

else

  color "31" "Process '$1' is not found!"
  color "31" "Usage: ./agora.sh PROCESS FLAGS."
  color "31" "PROCESS can be init"
  exit 1

fi
