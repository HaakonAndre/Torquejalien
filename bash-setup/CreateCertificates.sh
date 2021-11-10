#!/bin/bash

out=$(realpath -m $1)
[ x"$out" == x"" ] && echo "Usage: <out>/{certs,trusts}" && exit 1

TVO_CERTS=$out/globus
TVO_TRUSTS=$out/trusts

mkdir -p $TVO_CERTS $TVO_TRUSTS

function make_CA {
    mkdir -p "$1"
    pushd "$1"

    cert="$2"
    key="$3"
    subj="$4"

    openssl genrsa -out "$key" 1024
    openssl req -new -batch -key "$key" -x509 -days 365 -out "$cert" -subj "$subj"

    CA_hash=`openssl x509 -hash -noout -in cacert.pem`
    openssl x509 -inform PEM -in "cacert.pem" -outform DER -out "${CA_hash}.der"

    openssl pkcs12 -password pass: -export -in "cacert.pem" -name alien -inkey "cakey.pem" -out "alien.p12"

    cp alien.p12 *.der $TVO_TRUSTS
    openssl rehash .

    popd
}

function make_cert() {
    mkdir -p "$1"
    pushd "$1"

    cert="$2"
    key="$3"
    subj="$4"

    openssl req -nodes -newkey rsa:1024 -out "req.pem" -keyout "$key" -subj "$subj"
    openssl x509 -req -in "req.pem" -CA "$TVO_CERTS/CA/cacert.pem" -CAkey "$TVO_CERTS/CA/cakey.pem" -CAcreateserial -out "$cert"
    rm "req.pem"

    popd
}

pushd $TVO_CERTS

make_CA "CA" "cacert.pem" "cakey.pem" "/C=CH/O=JAliEn/CN=JAliEnCA"

make_cert "user"  "usercert.pem"  "userkey.pem"    "/C=CH/O=JAliEn/CN=jalien"
make_cert "host"  "hostcert.pem"  "hostkey.pem"    "/C=CH/O=JAliEn/CN=localhost.localdomain"
make_cert "authz" "AuthZ_pub.pem" "AuthZ_priv.pem" "/C=CH/O=JAliEn/CN=jAuth"
make_cert "SE"    "SE_pub.pem"    "SE_priv.pem"    "/C=CH/O=JAliEn/CN=TESTSE"

# NOTE: SE runs with user xrootd/975
# setting 644 instead of 640 to make certs readable across containers
find -name '*.pem' | xargs -n1 chmod 644
popd
