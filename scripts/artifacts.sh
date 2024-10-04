#!/bin/bash

# apply noir_bignum patch
sh scripts/patch_noir_bignum.sh

## Compile z-imburse
cd contracts/zimburse
aztec-nargo compile --force --silence-warnings

# if downloading github apply patch

aztec codegen ./target -o .

## Update the import
case "$OSTYPE" in
    darwin*)
        # macOS
        sed -i '' 's|target/z_imburse-ZImburse.json|./ZImburse.json|' ZImburse.ts
        ;;
    *)
        # Linux
        sed -i 's|target/z_imburse-ZImburse.json|./ZImburse.json|' ZImburse.ts
        sed -i "/export const ZImburseContractArtifact = loadContractArtifact(ZImburseContractArtifactJson as NoirCompiledContract);/i \\/\/@ts-ignore" ZImburse.ts
esac

## Move artifacts
mv ZImburse.ts ../../src/artifacts
mv target/z_imburse-ZImburse.json ../../src/artifacts/ZImburse.json

cd ../..
# clear
echo "Compiled ZImburse bytecode and typescript bindings"
