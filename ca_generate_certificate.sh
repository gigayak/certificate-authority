#!/bin/bash
set -Eeo pipefail

# TODO: This is an ideal candidate for using flag.sh.

ca_db=/opt/ca

subdomain="$1"
shift
domain="$1"
shift
if [[ -z "$subdomain" ]]
then
  echo "Usage: $(basename "$0") <subdomain>" >&2
  echo >&2
  echo "<subdomain> is 'git' when securing https://git.$domain/" >&2
  exit 1
fi

if [[ "$(basename "$subdomain")" != "$subdomain" ]]
then
  echo "$(basename "$0"): subdomain should not look like a directory" >&2
  echo "$(basename "$0"): possible directory traversal attack" >&2
  echo "$(basename "$0"): possible fat finger issue" >&2
  exit 1
fi

url="https://$subdomain.$domain/"
if [[ -e "$ca_db/certificates/$subdomain.crt" ]]
then
  echo "$(basename "$0"): certificate for URL '$url' already exists" >&2
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

echo "Generating a $bits bit private key."
certtool \
  --generate-privkey \
  --outfile "$ca_db/keys/$subdomain.key" \
  --bits "$bits"

organization="$(<"$ca_db/authority/organization")"

echo "Generating certificate template."
cat > "$ca_db/requests/$subdomain.tpl" <<EOF
organization = "$organization"
unit = "Internal Network (Servers)"
state = "California"
country = "US"
cn = "$subdomain.$domain"

serial = $serial
expiration_days = 365
dns_name = "$subdomain.$domain"

tls_www_server
encryption_key
EOF
for additional_name in "$@"
do
  echo "dns_name = \"$additional_name\"" \
    >> "$ca_db/requests/$subdomain.tpl"
done

echo "Generating signing request."
certtool \
  --generate-request \
  --load-privkey "$ca_db/keys/$subdomain.key" \
  --template "$ca_db/requests/$subdomain.tpl" \
  --outfile "$ca_db/requests/$subdomain.csr"

echo "Signing certificate."
certtool \
  --generate-certificate \
  --load-request "$ca_db/requests/$subdomain.csr" \
  --load-ca-certificate "$ca_db/authority/ca.crt" \
  --load-ca-privkey "$ca_db/authority/ca.key" \
  --template "$ca_db/requests/$subdomain.tpl" \
  --outfile "$ca_db/certificates/$subdomain.crt"

echo "Certificate should now exist at $ca_db/certificates/$subdomain.crt"
