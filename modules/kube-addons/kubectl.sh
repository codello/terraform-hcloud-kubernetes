#!/usr/bin/env sh

# This script is used by the kube-addons module instead of running kubectl directly. This module saves a kubeconfig
# passed via the environment before running kubectl thereby allowing credentials in the environment. This script can
# be called just as kubectl itself would.

creds=$(mktemp -d)
echo "$CA_CERT" > "$creds/ca.crt"
echo "$CLIENT_CERT" > "$creds/client.crt"
echo "$CLIENT_KEY" > "$creds/client.key"
chmod 600 "$creds/*"

if [ "$KUBECTL" = "DOWNLOAD" ]; then
    KUBECTL=~/.local/bin/kubectl
    mkdir -p $(dirname "$KUBECTL")
    version=$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)
    curl -L -o "$KUBECTL" https://storage.googleapis.com/kubernetes-release/release/$version/bin/linux/amd64/kubectl
    chmod +x "$KUBECTL"
fi

echo "KUBECTL is $KUBECTL"

echo "$STDIN" | $KUBECTL "--server=$ENDPOINT" \
                         "--certificate-authority=$creds/ca.crt" \
                         "--client-certificate=$creds/client.crt" \
                         "--client-key=$creds/client.key" \
                         "$@"
rm -rf "$creds"
