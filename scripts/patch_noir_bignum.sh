#!/bin/bash

# create variable pointing to noir github dependencies
case "$OSTYPE" in
    darwin*)
        # macOS
        noir_gh_path="/Users/${USER}/nargo/github.com/noir-lang"
        ;;
    *)
        # Linux
        noir_gh_path="/home/${USER}/nargo/github.com/noir-lang"
        ;;
esac

# check if directory exists. if not clone into
if [ -d "${noir_gh_path}/noir-bignumv0.3.3" ]; then
  echo ""
else
  git clone https://github.com/noir-lang/noir-bignum.git $noir_gh_path/noir-bignumv0.3.3
  cd $noir_gh_path/noir-bignumv0.3.3

  # hacky but actually use v0.3.4 and label as v0.3.3 to avoid unconstrained function error
  git checkout tags/v0.3.4 > /dev/null 2>&1
fi

  echo "\n\n\n##### IMPORTANT: This is actually using noir_bignumv0.3.4 labeled as noir_bignumv0.3.3 to circumvent an error #####\n\n\n"

cd $noir_gh_path/noir-bignumv0.3.3

# fix invalid quote format
case "$OSTYPE" in
    darwin*)
        # macOS
        sed -i '' 's/“Zexe”/"Zexe"/' ./src/fields/bls12_377Fq.nr
        sed -i '' 's/“Zexe”/"Zexe"/' ./src/fields/bls12_377Fr.nr
        ;;
    *)
        # Linux
        sed -i 's/“Zexe”/"Zexe"/' /src/fields/bls12_377Fq.nr
        sed -i 's/“Zexe”/"Zexe"/' /src/fields/bls12_377Fr.nr
        ;;
esac

echo "Patch applied to noir_bignum"