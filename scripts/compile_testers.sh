#!/bin/bash
cd ..
compile() {
    project=$1
    echo "Compiling $project circuit..."
    
    # Use pushd to change to the project directory and save the current directory
    pushd "$project" > /dev/null
    
    # Run the compile command
    nargo compile --force --silence-warnings
    
    cp ./target/$project.json ../../../src/artifacts/circuits/$project.json
    # Use popd to return to the previous directory
    popd > /dev/null
}

# Loop over every child folder in the examples directory
cd circuits/library_testers
for folder in *; do
    # only compile Linode and United for now
    if [ -d "$folder" ] && [[ "$folder" == "linode_email_verifier" || "$folder" == "united_email_verifier" ]]; then
        compile "$folder"
    fi
done
cd ..