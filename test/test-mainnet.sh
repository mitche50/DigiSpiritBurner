#!/bin/sh
forge test --fork-url $(grep ETH_URL .env | cut -d '=' -f2)