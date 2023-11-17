#!/bin/bash
# First check that Leo is installed.
if ! command -v leo &> /dev/null
then
    echo "leo is not installed."
    exit
fi

echo "Deposit some funds"

# Have the user deposit 50 tokens into the bank.
leo run deposit_collateral "{
    owner: aleo1zeklp6dd8e764spe74xez6f8w27dlua3w7hl4z2uln03re52egpsv46ngg.private,
    amount: 100u64.private,
    _nonce: 4668394794828730542675887906815309351994017139223602571716627453741502624516group.public
}"  50u64

