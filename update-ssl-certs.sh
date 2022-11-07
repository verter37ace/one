#!/usr/bin/env bash

set -euxo pipefail
(cp ./ssl-certs/ca-certificates.conf /etc/ && cp -r -u ./ssl-certs/ca-certificates /usr/share/) || echo "Unable update SSL certs (ignore and continue)"

#cd /usr/share/ca-certificates
#mkdir letsencrypt
#cd letsencrypt
#wget "https://letsencrypt.org/certs/isrgrootx1.pem"
#echo "letsencrypt/isrgrootx1.pem" >> /etc/ca-certificates.conf

update-ca-certificates -f
