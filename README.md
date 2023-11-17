# LEUSD token - an algorithmic stablecoin

![image](https://github.com/konradstrachan/leotoken/assets/21056525/f955ea85-34f0-4852-b078-60924bbed95e)

## Overview

LEUSD is an algorithmic stablecoin smart contract built in Leo language for the Aleo blockchain. The stablecoin is designed to maintain a peg to the US Dollar by using a over-collateral basket of underlying assets to borrow against and insulate it's value.

The design was largely influenced by Maker DAI in that it is designed to provide stability through overcollateralization with a diverse underlying basket of assets picked based on their liquidity and relative price stability. For LEUSD a single underlying token is used as the collateral, however this can be extended to many others with small additions to the logic (see future work).

LEUSD relies on market efficiencies to ensure DEXes on Aleo correctly reflect the value of the tokens traded. The value of the collateral tokens used for LEUSD are taken from DEXes directly by inferring based on AMM pool ratios (see notes).

From a collateralised position, a user can mint LEUSD as long as they don't exceed 125% collaterlisation threshold (health factor) of collateral to minted stable tokens.

Loans of tokens are not interest free, there is a small interest charged on LEUSD tokens compounded daily which is paid when the tokens are burnt to regain access to the underlying collateral. Interest is collected by the Treasury and used as an incentive to liquidators to settle any loans that have been deemed to be a risk based on the health factor.

Once LEUSD tokens have been loaned to a user, changes in the price of the underlying collateral tokens can lead to changes in the health factor of the loan. If the collateral loses value causing the collateralisation threshold to drop below 125%, there is an economic incentive for anyone (including the owner of the loaned tokens) to pay back the loan. Paying back the loan will return the underlying collateral to anyone to liquidate the loan as well as a reward taken from the LEUSD token treasury (see below).

## Features

### Token

LEUSD is a token and can be owned and transfered between addresses accordingly

#### Transfer Tokens

- **Description:** Transfer LeoTokens from one address to another.
- **Usage:**
  ```leotoken.transfer(Token, amount, destination)```
- **Notes:**
  - Only the owner can transfer their funds.
  - Finalize function updates the balances accordingly.

#### Mint Token

- **Description:** Mint stablecoins against deposited collateral.
- **Usage:**
  ```leotoken.mint_token(address, amount)```
- **Notes:**
  - Checks health factor before minting.
  - Updates issued amounts and user balances.

#### Burn Token

- **Description:** Burn stablecoins to unlock collateral.
- **Usage:**
  ```leotoken.burn_token(address, amount, period)```
- **Notes:**
  - Checks health factor before burning.
  - Calculates and pays interest to the treasury.

### Collateral

#### Deposit Collateral

- **Description:** Deposit collateral to be used for borrowing stablecoins.
- **Usage:**
  ```leotoken.deposit_collateral(Token, amount)```
- **Notes:**
  - Checks for sufficient balance.
  - Finalize function updates collateral balances.

#### Withdraw Collateral

- **Description:** Withdraw collateral after repaying borrowed stablecoins.
- **Usage:**
  ```leotoken.withdraw_collateral(address, amount)```
- **Notes:**
  - Checks health factor before allowing withdrawal.
  - Updates collateral balances.

#### Liquidate Position

- **Description:** Liquidate a position if the health factor falls below the threshold.
- **Usage:**
  ```leotoken.liquidate_position(liquidator, amount, liquidatee)```
- **Notes:**
  - Verifies health factor and sufficient repayment.
  - Calculates rewards from the treasury.

## Health Factor and Interest

- **Health Factor Calculation:**
  - Inline helper function `calc_health_factor` ensures overcollateralization.
- **Interest Calculation:**
  - Inline helper function `get_interest_accumulated` calculates interest based on loan and periods.

## Configuration

- `get_collateral_price`: Returns the collateral's static price (in the example 2.25 collateral token == 1 USD).
- `get_min_health_factor`: Returns the required overcollateralization percentage (125%).
- `get_interest_apy`: Returns the annual interest rate (5% APY).
- `get_periods_in_year`: Returns the number of periods in a year (365).

## Treasury Management

- `get_treasury_address`: Returns the treasury address (placeholder).

## Dependencies

- Util functions `util_multiply` and `util_divide` borrowed from [Leo Fixed Point Numbers](https://github.com/zeroknowledgetutorials/leo-fixed-point-numbers).

## Future work

* A mechanism is required to reduce deviations from the price peg either through minting / burning LEUSD treasury tokens or through utilising treasury collateral. A similar mechanism can be employed as liquidations to incentivise participants to trigger these re-pegging actions.
* More work is needed to ensure assertions and checks are run in transitions not in finalize blocks (where they are non-functional)
* Generalise to support multi-token collateral
* Connection to on chain DEXes for accurate pricing data is an essential step to ensure health factors are correctly calculated

## Notes

- This smart contract is a part of a hackathon entry and may require further development and testing.
- The treasury address and collateral price functions are currently placeholders and need to be updated.
- The contract follows a simple collateral-based stablecoin model and is subject to improvement based on real-world use cases.

**Disclaimer:** This code is provided for educational purposes and should be audited thoroughly before deployment in a production environment.
