#!/bin/bash
cd ..
compile() {
    project=$1
    echo "Compiling $project circuit..."
    
    # Use pushd to change to the project directory and save the current directory
    pushd "$project" > /dev/null
    
    # Run the compile command
    nargo compile --force --silence-warnings
    
    cp ./target/$project.json ../../../src/circuits/$project.json
    # Use popd to return to the previous directory
    popd > /dev/null
}

# Loop over every child folder in the examples directory
cd circuits/library_testers
for folder in *; do
    if [ -d "$folder" ]; then
        compile "$folder"
    fi
done
cd ..