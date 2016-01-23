#!/bin/bash
set -Eeo pipefail

organization="$1"
if [[ -z "$organization" ]]
then
  echo "Usage: $(basename "$0") <organization name>" >&2
  echo >&2
  echo 'Initializes certificate authority data.  You need to run this' >&2
  echo 'prior to any `ca_generate_*.sh` calls.' >&2
  exit 1
fi

ca_db=/opt/ca
if [[ -e "$ca_db/.initialized" ]]
then
  echo "$(basename "$0"): certificate authority at '$ca_db' already exists" >&2
  exit 1
fi

mkdir -pv -m 0700 \
  "$ca_db/keys" \
  "$ca_db/requests" \
  "$ca_db/certificates" \
  "$ca_db/authority"

echo "$organization" > "$ca_db/authority/organization"

# Dumb assumption: all certs will be of the same strength.
bits=8192
echo "$bits" > "$ca_db/authority/bits"

# Initialize CA's serial numbering.
# TODO: This should be random!
echo 1 > "$ca_db/authority/serial"

# Generate CA key and cert.
certtool \
  --generate-privkey \
  --outfile "$ca_db/authority/ca.key" \
  --bits "$bits"

cat > "$ca_db/authority/ca.tpl" <<EOF
organization = "$organization"
unit = "Internal Network"
state = "California"
country = "US"
# Yes, that's a hell of a long CN -- trying to avoid acronyms?
cn = "$organization Internal Certificate Authority"
# TODO: Serial should be incremented when this certificate is re-generated.
serial = 1
expiration_days = 3650
ca
cert_signing_key
crl_signing_key
EOF

certtool \
  --generate-self-signed \
  --load-privkey "$ca_db/authority/ca.key" \
  --template "$ca_db/authority/ca.tpl" \
  --outfile "$ca_db/authority/ca.crt"

touch "$ca_db/.initialized"
