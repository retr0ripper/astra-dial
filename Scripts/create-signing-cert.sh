#!/usr/bin/env bash
# Creates a self-signed code-signing certificate, "Astra Dial Local Signing", in the login
# keychain. bundle.sh signs with it when present, which gives every build the same designated
# requirement, so macOS keeps Input Monitoring and Accessibility across rebuilds.
#
# Ad-hoc signing (the fallback) ties permissions to the build's hash, so each rebuild
# looks like a new app and macOS asks again.
set -euo pipefail

NAME="Astra Dial Local Signing"
KEYCHAIN="$HOME/Library/Keychains/login.keychain-db"

if security find-identity -p codesigning "$KEYCHAIN" | grep -q "\"$NAME\""; then
  echo "\"$NAME\" already exists."
  exit 0
fi

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

cat > "$WORK/cert.cnf" <<EOF
[req]
distinguished_name = dn
x509_extensions = ext
prompt = no
[dn]
CN = $NAME
[ext]
basicConstraints = critical, CA:false
keyUsage = critical, digitalSignature
extendedKeyUsage = critical, codeSigning
EOF

/usr/bin/openssl req -x509 -newkey rsa:2048 -nodes -days 3650 \
  -keyout "$WORK/key.pem" -out "$WORK/cert.pem" -config "$WORK/cert.cnf" 2>/dev/null

# A throwaway password: security import needs one for the .p12, and the file is deleted on exit.
PASS="astra-$RANDOM$RANDOM"
/usr/bin/openssl pkcs12 -export -inkey "$WORK/key.pem" -in "$WORK/cert.pem" \
  -name "$NAME" -out "$WORK/cert.p12" -passout "pass:$PASS" 2>/dev/null

# -T lets codesign use the private key without a prompt.
security import "$WORK/cert.p12" -k "$KEYCHAIN" -P "$PASS" -T /usr/bin/codesign >/dev/null

echo "Created \"$NAME\" in the login keychain."
echo "If codesign asks to use the key, choose Always Allow."
