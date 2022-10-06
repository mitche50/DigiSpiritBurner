#!/usr/bin/env bash

if [ -f .env ]
then
  export $(cat .env | xargs) 
else
    echo "Please set your .env file"
    exit 1
fi

forge create ./src/Adventure/HeroAdventure.sol:HeroAdventure -i --rpc-url 'https://goerli.infura.io/v3/'${INFURA_API_KEY} --private-key ${PRIVATE_KEY} --verify --build-info --constructor-args "0xc43d95839DD258ecbCCeE8629E332E14de0fef65" "0x2FA2dE63B2e72D71B48f7688518E306bDd582d85" "0xFad153B5d16405438a4e20c6d8dadA73Fb9FF54e"