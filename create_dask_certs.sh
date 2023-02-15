#!/bin/sh

# Author: Enric Tejedor 2023

# Generates a self-signed certificate to be used by Dask processes (client,
# scheduler and workers) within a SWAN session.
# Dask clusters created from SWAN can be configured with TLS support by
# pointing to the server certificate, private key and CA certificate that are
# generated below.

CERT_DIR=$1
TEMP_DIR=`mktemp -d`
export RANDFILE="$TEMP_DIR/.rnd"

ORGANIZATIONAL_UNIT="SWAN"
ORGANIZATION="CERN"
LOCALITY="Geneva"
COUNTRY="CH"
CA_COMMON_NAME="SWAN CA"
COMMON_NAME="SWAN Dask server"

CA_CERT="ca.crt"
CA_KEY="ca.key"
SERVER_CERT="server.crt"
SERVER_KEY="server.key"

CSR_CONF="csr.conf"
CSR="server.csr"
CERT_CONF="cert.conf"

# Create CA private key and certificate
openssl genrsa -out $CERT_DIR/$CA_KEY 2048
openssl req -x509 \
            -sha256 \
            -days 30 \
            -nodes \
            -subj "/CN=$CA_COMMON_NAME/OU=$ORGANIZATIONAL_UNIT/O=$ORGANIZATION/L=$LOCALITY/C=$COUNTRY" \
            -key $CERT_DIR/$CA_KEY \
            -out $CERT_DIR/$CA_CERT

# Create server private key
openssl genrsa -out $CERT_DIR/$SERVER_KEY 2048

# Create certificate signing request configuration
cat > $TEMP_DIR/$CSR_CONF <<EOF
[ req ]
default_bits = 2048
prompt = no
default_md = sha256
distinguished_name = dn

[ dn ]
C = $COUNTRY
L = $LOCALITY
O = $ORGANIZATION
OU = $ORGANIZATIONAL_UNIT
CN = $COMMON_NAME
EOF

# Create certificate signing request
openssl req -new \
            -config $TEMP_DIR/$CSR_CONF \
            -key $CERT_DIR/$SERVER_KEY \
            -out $TEMP_DIR/$CSR

# Create external config file for the certificate
cat > $TEMP_DIR/$CERT_CONF <<EOF
authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
keyUsage = digitalSignature, keyEncipherment
EOF

# Create self-signed certificate
openssl x509 -req \
             -sha256 \
             -days 30 \
             -CA $CERT_DIR/$CA_CERT \
             -CAkey $CERT_DIR/$CA_KEY \
             -CAcreateserial \
             -extfile $TEMP_DIR/$CERT_CONF \
             -in $TEMP_DIR/$CSR \
             -out $CERT_DIR/$SERVER_CERT

# Cleanup
rm -rf $TEMP_DIR