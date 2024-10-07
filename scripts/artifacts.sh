#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"

# check_versions() {

# }

## Compile a contract artifact
## $1: the directory/ contract name in snake case
compile_artifact() {

    ### determine if the project is a contract
    [[ -f $1/Nargo.toml ]] || return 1
    grep -q 'type = "contract"' "$project/Nargo.toml" || return 1

    ### get pascal case for project name from snake case
    case "$OSTYPE" in
    darwin*)
        # macOS
        contract_name=$(echo "$project" | sed '' 's/_\([a-z]\)/\U\1/g' | sed '' 's/^\([a-z]\)/\U\1/')
        ;;
    *)
        # Linux
        contract_name=$(echo "$project" | sed 's/_\([a-z]\)/\U\1/g' | sed 's/^\([a-z]\)/\U\1/')
        ;;
    esac

    ### Generate typescript bindings
    aztec codegen ./target/$project-$contract_name.json -o .

    echo "Compiled $contract_name bytecode and typescript bindings"

    ## Update the imports in the generated typescript bindings
    case "$OSTYPE" in
    darwin*)
        # macOS
        sed -i '' "s|target/${project}-${contract_name}.json|./${contract_name}.json|" $contract_name.ts
        sed -i '' "export const ${contract_name}ContractArtifact = loadContractArtifact(${contract_name}ContractArtifactJson as NoirCompiledContract);/i \\/\/@ts-ignore" $contract_name.ts
    
        ;;
    *)
        # Linux
        contract_name=$(echo "$project" | sed 's/_\([a-z]\)/\U\1/g' | sed 's/^\([a-z]\)/\U\1/')
        sed -i "s|target/${project}-${contract_name}.json|./${contract_name}.json|" $contract_name.ts
        sed -i "/export const ${contract_name}ContractArtifact = loadContractArtifact(${contract_name}ContractArtifactJson as NoirCompiledContract);/i \\/\/@ts-ignore" $contract_name.ts
        ;;
    esac

    ## Move artifacts
    mv $contract_name.ts ../src/artifacts
    mv target/$project-$contract_name.json ../src/artifacts/$contract_name.json
}

### MAIN
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"

### Check the versions of aztec dependencies

### Patch noir bignum to work with aztec-nargo
### TODO: remove with 0.35.0 release
sh $SCRIPT_DIR/patch_noir_bignum.sh

### Compile the ZImburse workspace
cd $SCRIPT_DIR/../contracts
aztec-nargo compile --force --silence-warnings
echo "###NOTE: If the above error is 'could not read z_imburse_contract_registry', ignore###"
echo "Compiled Z-Imburse Contracts"

for project in *; do
    if [ -d "$project" ]; then
        compile_artifact "$project"
    fi
done

echo Z-Imburse Artifact Compilation Complete!
