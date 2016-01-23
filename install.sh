#!/bin/bash
set -Eeo pipefail
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

scripts=()
scripts+=("ca_init")
scripts+=("ca_generate_certificate")
scripts+=("ca_generate_client_certificate")
for script in "${scripts[@]}"
do
  cp -v "$DIR/$script.sh" "/usr/bin/$script"
  chmod +x "/usr/bin/$script"
done
