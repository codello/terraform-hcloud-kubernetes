#!/usr/bin/env sh

# This script is used by the kube-addons module instead of running kubectl directly. This module saves a kubeconfig
# passed via the environment before running kubectl thereby allowing credentials in the environment. This script can
# be called just as kubectl itself would.

kubeconfig=$(mktemp)
chmod 600 "$kubeconfig"
echo "$KUBECONFIG" > "$kubeconfig"
echo "$STDIN" | kubectl --kubeconfig "$kubeconfig" "$@"
rm "$kubeconfig"
