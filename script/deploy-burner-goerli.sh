#!/usr/bin/env bash

if [ -f .env ]
then
  export $(cat .env | xargs) 
else
    echo "Please set your .env file"
    exit 1
fi

forge create ./src/DigiSpiritBurner.sol:DigiSpiritBurner -i --rpc-url 'https://goerli.infura.io/v3/'${INFURA_API_KEY} --private-key ${PRIVATE_KEY} --verify --build-info --constructor-args "0x2FA2dE63B2e72D71B48f7688518E306bDd582d85" "0xc43d95839DD258ecbCCeE8629E332E14de0fef65" "0xFad153B5d16405438a4e20c6d8dadA73Fb9FF54e" "0xC93F7Fd9be73f14E8419e87014A09E6C88cEdCe7" "0xB4FBF271143F4FBf7B91A5ded31805e42b2208d6"