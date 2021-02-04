#!/usr/bin/env sh

set -e

# This script is used by the kube-addons module instead of running kubectl directly. This module saves a kubeconfig
# passed via the environment before running kubectl thereby allowing credentials in the environment. This script can
# be called just as kubectl itself would.

# The save_creds function stores the contents of the environment variables $CA_CERT, $CLIENT_CERT, and $CLIENT_KEY to
# the $1 directory.
save_creds() {
    echo "$CA_CERT" > "$1/ca.crt"
    echo "$CLIENT_CERT" > "$1/client.crt"
    echo "$CLIENT_KEY" > "$1/client.key"
    chmod 600 "$1"/*
}

# This function handles the special case where $KUBECTL is equal to the string "DOWNLOAD". If not already present this
# function downloads the kubectl binary. The output of this function is the path to the kubectl executable.
prepare_kubectl() {
    if [ "$KUBECTL" = "DOWNLOAD" ]; then
        # We use the following directory as a locking mechanism if multiple instances of this script run in parallel.
        until mkdir /tmp/kubectl-download-lock 2> /dev/null; do
            sleep 1
        done
        if [ ! -f "$1" ]; then
            mkdir -p $(dirname "$1")
            version=$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)
            curl -sLo "$1" "https://storage.googleapis.com/kubernetes-release/release/$version/bin/linux/amd64/kubectl"
            chmod +x "$1"
        fi
        rmdir /tmp/kubectl-download-lock
        echo "$1"
    else
        echo "$KUBECTL"
    fi
}

# Writes the contents of the $STDIN variable to the file at path $1. If $STDIN does not exist $STDIN0, $STDIN1, ...
# are concatenated at $1 and separated by $2.
prepare_stdin() {
    manifest=$(mktemp)
    if [ -n "$STDIN" ]; then
        echo "$STDIN" > "$manifest"
    else
        i=0
        eval value=\"\$STDIN$i\"
        while [ -n "$value" ]; do
            if [ "$i" -ne 0 ]; then
                echo -n "$1" >> "$manifest"
            fi
            echo -n "$value" >> "$manifest"
            i=$((i+1))
            eval value=\"\$STDIN$i\"
        done
    fi
    echo "$manifest"
}

tmp=$(mktemp -d)
save_creds "$tmp"
kubectl=$(prepare_kubectl ~/.local/bin/kubectl)
manifest=$(prepare_stdin "---")

cat "$manifest" | $kubectl "--server=$ENDPOINT" \
    "--certificate-authority=$tmp/ca.crt" \
    "--client-certificate=$tmp/client.crt" \
    "--client-key=$tmp/client.key" \
    "$@"

rm -rf "$tmp"
rm -f "$manifest"
