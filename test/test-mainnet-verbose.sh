#!/bin/sh
forge test --fork-url $(grep ETH_RPC_URL .env | cut -d '=' -f2) --fork-block-number 15599160 -vvv