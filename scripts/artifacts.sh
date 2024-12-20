#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"

## Adds the compiled token contract
get_token_contract_bytecode() {
    token_bytecode_path="${CONTRACT_DIR}/../node_modules/@aztec/noir-contracts.js/artifacts/token_contract-Token.json"
    cp $token_bytecode_path "${CONTRACT_DIR}/target"
}

## Compile a contract artifact
## $1: the directory/ contract name in snake case
compile_artifact() {
    ### determine if the project is a contract
    [[ -f $project/Nargo.toml ]] || return 1
    grep -q 'type = "contract"' "$project/Nargo.toml" || return 1

    ### get pascal case for project name from snake case
    case "$OSTYPE" in
    darwin*)
        # macOS
        contract_name=$(echo "$project" | awk -F'_' '{for(i=1;i<=NF;i++){printf toupper(substr($i,1,1)) substr($i,2)}}')
        ;;
    *)
        # Linux
        contract_name=$(echo "$project" | sed 's/_\([a-z]\)/\U\1/g' | sed 's/^\([a-z]\)/\U\1/')
        ;;
    esac

    ### Generate typescript bindings
    VERSION=0.67.1 aztec codegen ./target/$project-$contract_name.json -o ./target

    echo "Compiled $contract_name bytecode and typescript bindings"

    ## Update the imports in the generated typescript bindings
    case "$OSTYPE" in
    darwin*)
        # macOS
        echo $project
        contract_name=$(echo "$project" | tr '_' ' ' | awk '{for(i=1;i<=NF;i++)sub(/./,toupper(substr($i,1,1)),$i)}1' | tr -d ' ')
        sed -i '' "s|target/${project}-${contract_name}.json|./${contract_name}.json|" $contract_name.ts
        # do not align last line as it adds extra whitespace
        sed -i '' '
/export const '"${contract_name}"'ContractArtifact = loadContractArtifact('"${contract_name}"'ContractArtifactJson as NoirCompiledContract);/ {
    i\
//@ts-ignore
}
' "${contract_name}.ts"
        ;;
    *)
        # Linux
        contract_name=$(echo "$project" | sed 's/_\([a-z]\)/\U\1/g' | sed 's/^\([a-z]\)/\U\1/')
        sed -i "s|./${project}-${contract_name}.json|./${contract_name}.json|" target/$contract_name.ts
        sed -i "/export const ${contract_name}ContractArtifact = loadContractArtifact(${contract_name}ContractArtifactJson as NoirCompiledContract);/i \\/\/@ts-ignore" target/$contract_name.ts
        ;;
    esac

    ## Move artifacts
    cp target/$contract_name.ts ../src/artifacts/contracts
    cp target/$project-$contract_name.json ../src/artifacts/contracts/$contract_name.json
}

### MAIN
# NOIR_BIGNUM_PATH="$HOME/nargo/github.com/noir-lang/noir-bignum/v0.4.1/src/tests/runtime_bignum_test.nr"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
CONTRACT_DIR="${SCRIPT_DIR}/../contracts"
### Check the versions of aztec dependencies

### Comment out the test macro from noir-bignum
# sed -i '' 's/^\(\s*#\[make_test.*\)/\/\/\1/' $NOIR_BIGNUM_PATH

### Compile the ZImburse workspace
cd $CONTRACT_DIR

# ### Compile the contract
VERSION=0.67.1 aztec-nargo compile --silence-warnings

### Only run codegen if "true" is passed as an argument
if [ "$1" == "true" ]; then
    for project in *; do
        if [ -d "$project" ]; then
            compile_artifact "$project"
        fi
    done
else
    ### Otherwise compiling for TXE and dont need abi but do need token bytecode
    get_token_contract_bytecode
fi

echo "Z-Imburse Artifact Compilation Complete!"