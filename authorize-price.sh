#!/usr/bin/env bash

set -euo pipefail

if [[ "$IN_NIX_SHELL" != "yes" ]]; then
    echo "This command must be run via nix-shell"
    exit 1
fi
# if [[ -z "$BIN_DIR" ]]; then
#     echo "This command must be called without \"./\""
#     exit 1
# fi

CONTRACTS=out/addresses.json

if [[ $# -eq 0 ]]; then
  echo "Usage: $0 account [...]"
  exit 1
fi
accounts=$@
if [[ ! -f $CONTRACTS ]]; then
    echo "File missing: $CONTRACTS"
    exit 1
fi

pips=$(jq -r '. | to_entries | map(select(.key | test("^PIP_"))) | map(.value) | .[]' $CONTRACTS)
vals=$(jq -r '. | to_entries | map(select(.key | test("^VAL_"))) | map(.value) | .[]' $CONTRACTS)

echo chain: $(seth chain)
echo accounts: $accounts
echo pips: $pips
echo vals: $vals

set -x

guard=0x$(seth call $(echo $vals | cut -d' ' -f1) 'authority()(address)')
if [[ "$guard" == "0x0000000000000000000000000000000000000000" ]]; then
  echo -e "\n *** deploying the guardian\n"
  guard=$(env DAPP_OUT="$DAPP_LIB/dss-deploy/out" dapp create DSGuard)
fi

poke=$(seth --to-bytes32 $(seth sig 'poke(bytes32)'))
for account in $accounts; do
  for val in $vals; do
    echo -e "\n *** granting $val to user $account\n"
    seth send $val 'setAuthority(address)' $guard
    seth send $guard 'permit(address,address,bytes32)' $account $val $poke
  done

  for pip in $pips; do
    echo -e "\n *** granting $pip to user $account\n"
    seth send $pip 'kiss(address)' $account
  done
done
