source .env

forge script script/DeployStupidContract.s.sol --fork-url ${BASE_SEPOLIA_NODE_RPC_URL} --broadcast --use 0.8.23 --slow --chain-id 84532 --etherscan-api-key ${BASESACN_API_KEY} --verify

# If verification fails, it will be re-verified here.
if [ $? -eq 0 ]; then
        contractAddress=$(jq -r '.Base_Sepolia.stupidAccount' script/output/Address.json)

        forge verify-contract --watch --chain 84532 --verifier "etherscan" --etherscan-api-key ${BASESACN_API_KEY} --compiler-version 0.8.23 --constructor-args $(cast abi-encode "constructor(address)" ${ENTRYPOINT_ADDRESS}) ${contractAddress} "src/StupidAccount.sol:StupidAccount"

        contractAddress=$(jq -r '.Base_Sepolia.stupidPaymaster' script/output/Address.json)

        forge verify-contract --watch --chain 84532 --verifier "etherscan" --etherscan-api-key ${BASESACN_API_KEY} --compiler-version 0.8.23 --constructor-args $(cast abi-encode "constructor(address)" ${ENTRYPOINT_ADDRESS}) ${contractAddress} "src/StupidPaymaster.sol:StupidPaymaster"
fi
