#!/usr/bin/env bash

if [ -f .env ]
then
  export $(cat .env | xargs) 
else
    echo "Please set your .env file"
    exit 1
fi

forge create ./src/Adventure/DigiDaigaku.sol:DigiDaigaku -i --rpc-url 'https://goerli.infura.io/v3/'${INFURA_API_KEY} --private-key ${PRIVATE_KEY} --verify
forge create ./src/Adventure/DigiDaigakuHeroes.sol:DigiDaigakuHeroes -i --rpc-url 'https://goerli.infura.io/v3/'${INFURA_API_KEY} --private-key ${PRIVATE_KEY} --verify
forge create ./src/Adventure/DigiDaigakuSpirits.sol:DigiDaigakuSpirits -i --rpc-url 'https://goerli.infura.io/v3/'${INFURA_API_KEY} --private-key ${PRIVATE_KEY} --verify
