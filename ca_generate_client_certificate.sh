#!/bin/bash
set -Eeo pipefail

# TODO: This is an ideal candidate for using flag.sh.

ca_db=/opt/ca

username="$1"
machinename="$2"
domain="$3"
client_name="$4"
if (( "$#" != 4 ))
then
  echo "Usage: $(basename "$0") <username> <hostname> <domain> <full name>" >&2
  echo >&2
  echo "username should be a UNIX username, i.e. 'jgilik'" >&2
  echo "machinename should be a FQDN corresponding to the target machine" >&2
  echo "full name should be a human legible name, i.e. 'John Gilik'" >&2
  exit 1
fi

stripped_machinename="$(echo "$machinename" \
  | sed -nre 's@^([^.]+)(\..*)?$@\1@gp')"

if [[ -e "$ca_db/certificates/client.$username@$machinename.crt" ]]
then
  echo "$(basename "$0"): certificate for user '$username' on" \
    "machine '$machinename' already exists" >&2
  exit 1
fi
echo "Generating certificate for URL '$url'."

bits_file="$ca_db/authority/bits"
bits="$(<"$bits_file")"
if [[ -z "$bits" ]] || (( ! "$bits" ))
then
  echo "$(basename "$0"): failed to read key strength from file '$bits_file'">&2
  exit 1
fi

serial_file="$ca_db/authority/serial"
serial="$(<"$serial_file")"
if [[ -z "$serial" ]] || (( ! "$serial" ))
then
  echo "$(basename "$0"): failed to read next serial from file '$serial_file'" >&2
  exit 1
fi
echo "$(expr "$serial" \+ 1)" > "$serial_file"

organization="$(<"$ca_db/authority/organization")"

echo "Generating a $bits bit private key."
certtool \
  --generate-privkey \
  --outfile "$ca_db/keys/client.$username@$machinename.key" \
  --bits "$bits"

echo "Generating certificate template."
cat > "$ca_db/requests/client.$username@$machinename.tpl" <<EOF
organization = "$organization"
unit = "Internal Network (Clients)"
state = "California"
country = "US"
cn = "$client_name"
email = "$username@$machinename"

serial = $serial
expiration_days = 365

tls_www_client
encryption_key
signing_key
EOF

echo "Generating signing request."
certtool \
  --generate-request \
  --load-privkey "$ca_db/keys/client.$username@$machinename.key" \
  --template "$ca_db/requests/client.$username@$machinename.tpl" \
  --outfile "$ca_db/requests/client.$username@$machinename.csr"

echo "Signing certificate."
certtool \
  --generate-certificate \
  --load-request "$ca_db/requests/client.$username@$machinename.csr" \
  --load-ca-certificate "$ca_db/authority/ca.crt" \
  --load-ca-privkey "$ca_db/authority/ca.key" \
  --template "$ca_db/requests/client.$username@$machinename.tpl" \
  --outfile "$ca_db/certificates/client.$username@$machinename.crt"

echo "Converting to PKCS #12 format."
certtool \
  --to-p12 \
  --outder \
  --load-certificate "$ca_db/certificates/client.$username@$machinename.crt" \
  --load-privkey "$ca_db/keys/client.$username@$machinename.key" \
  --outfile "$ca_db/keys/client.$username@$machinename.p12" \
  --empty-password \
  --p12-name "MAR Client: $username@$machinename"

echo "Certificate should now exist at $ca_db/keys/client.$username@$machinename.p12"
