#!/bin/bash

sh scripts/patch_noir_bignum.sh
## Compile z-imburse
cd contracts
aztec-nargo compile --force --silence-warnings

# if downloading github apply patch
aztec codegen ./target/zimburse_escrow-ZImburseEscrow.json -o .

## Update the import
case "$OSTYPE" in
    darwin*)
        # macOS
        sed -i '' 's|target/zimburse_escrow-ZImburseEscrow.json|./ZImburseEscrow.json|' ZImburseEscrow.ts
        sed -i '' "/export const ZImburseEscrowContractArtifact = loadContractArtifact(ZImburseEscrowContractArtifactJson as NoirCompiledContract);/i \\/\/@ts-ignore" ZImburseEscrow.ts
        ;;
    *)
        # Linux
        sed -i 's|target/zimburse_escrow-ZImburseEscrow.json|./ZImburseEscrow.json|' ZImburseEscrow.ts
        sed -i "/export const ZImburseEscrowContractArtifact = loadContractArtifact(ZImburseEscrowContractArtifactJson as NoirCompiledContract);/i \\/\/@ts-ignore" ZImburseEscrow.ts
esac

## Move artifacts
mv ZImburseEscrow.ts ../src/artifacts
mv target/zimburse_escrow-ZImburseEscrow.json ../src/artifacts/ZImburseEscrow.json

cd ../..
# clear
echo "Compiled ZImburse bytecode and typescript bindings"
