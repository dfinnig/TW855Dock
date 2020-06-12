#!/bin/sh

keys="${1}"

keyservers="
hkp://p80.pool.sks-keyservers.net:80
ha.pools.sks-keyservers.net
ipv4.pools.sks-keyservers.net
hkp://pgp.mit.edu:80
keyserver.gpg.com
${2}"

for keyserver in ${keyservers}; do
    echo "Attmepting to import gpg keys from ${keyserver}"
    gpg --keyserver "${keyserver}" --recv-keys "${keys}" && exit
done
