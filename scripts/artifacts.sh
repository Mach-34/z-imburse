#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"

# check_versions() {

# }

## Compile a contract artifact
## $1: the directory/ contract name in snake case
compile_artifact() {

    pushd "$project" >/dev/null
    ### determine if the project is a contract
    [[ -f Nargo.toml ]] || { popd >/dev/null; return 1; }
    grep -q 'type = "contract"' "Nargo.toml" || { popd >/dev/null; return 1; }
    set -e

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

    ### Compile the contract
    aztec-nargo compile --silence-warnings

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
    mv $contract_name.ts ../../src/artifacts/contracts
    mv target/$project-$contract_name.json ../../src/artifacts/contracts/$contract_name.json
    popd >/dev/null
}

### MAIN
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"

### Check the versions of aztec dependencies

### Patch noir bignum to work with aztec-nargo
### TODO: remove with 0.35.0 release
sh $SCRIPT_DIR/patch_noir_bignum.sh

### Compile the ZImburse workspace
cd $SCRIPT_DIR/../contracts
ls
echo "Compiled Z-Imburse Contracts"

for project in *; do
    if [ -d "$project" ]; then
        compile_artifact "$project"
    fi
done

echo Z-Imburse Artifact Compilation Complete!
