#!/bin/bash

# TODO: Figure out why this can't be ran a directory above
cd scripts

sh compile_testers.sh

cd ..

sh scripts/artifacts.sh