#!/bin/bash
# First check that Leo is installed.
if ! command -v leo &> /dev/null
then
    echo "leo is not installed."
    exit
fi

echo "Deposit some funds as collateral"

leo run deposit_collateral "{
    owner: aleo1zeklp6dd8e764spe74xez6f8w27dlua3w7hl4z2uln03re52egpsv46ngg.private,
    amount: 100u32.private,
    _nonce: 4668394794828730542675887906815309351994017139223602571716627453741502624516group.public
}"  50u32

echo "Mint LEUSD tokens from collateral"

# Have the user mint 100 LEUSD tokens from their collateral
leo run mint_token aleo1zeklp6dd8e764spe74xez6f8w27dlua3w7hl4z2uln03re52egpsv46ngg 100u32

echo "Send some of these tokens to another address"

leo run transfer "{
    owner: aleo1zeklp6dd8e764spe74xez6f8w27dlua3w7hl4z2uln03re52egpsv46ngg.private,
    amount: 100u32.private,
    _nonce: 4668394794828730542675887906815309351994017139223602571716627453741502624516group.public
}" 10u32 aleo1zeklp6dd8e764spe74xez6f8w27dlua3w7hl4z2uln03re52egpsv46ngg

echo "Repay some of the borrowed LEUSD tokens"

# Simulating the passage of 10 days
leo run burn_token aleo1zeklp6dd8e764spe74xez6f8w27dlua3w7hl4z2uln03re52egpsv46ngg 10u32 10u32

echo "Withdraw available collateral"

leo run withdraw_collateral aleo1zeklp6dd8e764spe74xez6f8w27dlua3w7hl4z2uln03re52egpsv46ngg 10u32
