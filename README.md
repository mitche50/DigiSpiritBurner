# Digi Spirit Burner Contract
A staking contract which allows users to stake their Digi Genesis NFT to allow other users to pay to mint Warrior Spirits for use in the upcoming Limit Break games.

### Testing
Tests for this contract run on a fork of mainnet which requires you to provide an RPC.  There are shell scripts in the `test` folder which facilitate these if you provide the RPC in a `.env` file.

1. Create a `.env` file in the root of the project with `ETH_RPC_URL=` and assign an RPC link to this using alchemy, infura or your RPC provider of choice.
2. To run tests, run `./test/test-mainnet.sh`
3. To run tests with verbose outputs run `./test/test-mainnet-verbose.sh`