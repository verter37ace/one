#!/usr/bin/env bash

set -euxo pipefail
(cp ./ssl-certs/ca-certificates.conf /etc/ && cp -r -u ./ssl-certs/ca-certificates /usr/share/) || echo "Unable update SSL certs (ignore and continue)"

#cd /usr/share/ca-certificates
#mkdir letsencrypt
#cd letsencrypt
#wget "https://letsencrypt.org/certs/isrgrootx1.pem"
#echo "letsencrypt/isrgrootx1.pem" >> /etc/ca-certificates.conf

update-ca-certificates -f

# apt-key adv --refresh-keys || apt-key adv --keyserver keys.gnupg.net --refresh-keys
apt-key adv --recv-keys --keyserver keyserver.ubuntu.com EF0F382A1A7B6500
apt-key adv --keyserver keyserver.ubuntu.com --refresh-keys

if grep -q jessie /etc/os-release; then
  echo 'Acquire::Check-Valid-Until no;' > /etc/apt/apt.conf.d/99-no-check-valid-until
  # find /etc/apt -name '*.list' | xargs -r sed -i 's|//deb.debian.org|//archive.debian.org|g'
  # apt-key adv --recv-keys --keyserver hkp://keyserver.ubuntu.com 7638D0442B90D010
  wget https://deb.freexian.com/extended-lts/pool/main/f/freexian-archive-keyring/freexian-archive-keyring_2022.06.08_all.deb && dpkg -i freexian-archive-keyring_2022.06.08_all.deb
  wget https://deb.freexian.com/extended-lts/archive-key.gpg -O /etc/apt/trusted.gpg.d/freexian-archive-extended-lts.gpg
  echo "deb http://deb.freexian.com/extended-lts jessie main contrib non-free" > /etc/apt/sources.list.d/extended-lts.list
  apt-key list | grep "expired: " | sed -ne 's|pub .*/\([^ ]*\) .*|\1|gp' | xargs -r -n1 apt-key adv --keyserver keyserver.ubuntu.com --recv-keys
  apt-key list | grep expired
fi
