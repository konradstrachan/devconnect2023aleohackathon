// High level design
// [x] Supply asset collateral to vault for address
// [ ] borrow token (up to health factor) for address
// [ ] Repay token and interest
// [ ] Interest paid to protocol safety fund on redemption
// [ ] Health factor based liquidations by anyone
//     [ ] Earn part of safety fund
//     [ ] loan amount / all loan amounts => fractional share of safety fund
//     [ ] scaling factor based on health factor ?
//     [ ] Incentivise others to liquidate loan
//
// [ ] Use the aleoswap pool price for reference
//


// The 'leotoken' program.
program leotoken.aleo {
    // Mapping of supplied collateral balances for addresses
    mapping collateral_balances: address => u64;
    // Mapping of issues tokens against collateral
    mapping issued_amount: address => u64;

    // LEO stable token
    // - 'owner'  : The address of the account that owns the record associated with this token.
    // - 'amount' : The amount of tokens owned by the account.
    // TODO store interest rate and starting time to work out interest?
    record Token {
        owner: address,
        amount: u64,
    }

    //////////////////////////////////////////////////////////
    // deposit_collateral
    //
    // Deposit collateral which can then be borrowed against
    // Improvements : multitoken collateral
    transition deposit_collateral(token: Token, amount: u64) -> Token {
        let difference: u64 = token.amount - amount;

        let remaining: Token = Token {
            owner: token.owner,
            amount: difference,
        };

        return remaining then finalize(token.owner, amount);
    }

    finalize deposit_collateral(depositor: address, amount: u64) {
        let current_amount: u64 = Mapping::get_or_use(collateral_balances, depositor, 0u64);
        Mapping::set(collateral_balances, depositor, current_amount + amount);
    }

    //////////////////////////////////////////////////////////
    // withdraw_collateral
    //
    // Withdrawl collateral that was used to borrow against
    // TODO : check the loan health factor
    transition withdraw_collateral(recipient: address, amount: u64) -> Token {
        let token: Token = Token {
            owner: recipient,
            amount: amount,
        };

        // TODO Test current health factor of loan and refuse to return if falls below health factor

        return token then finalize(recipient, amount);
    }

    finalize withdraw_collateral(recipient: address, amount: u64) {
        let current_amount: u64 = Mapping::get_or_use(collateral_balances, recipient, 0u64);
        Mapping::set(collateral_balances, recipient, current_amount - amount);
    }

    transition main(public a: u32, b: u32) -> u32 {
        let c: u32 = a + b;
        return c;
    }

    transition calc_health_factor(collateral: u32, issued: u32, collateral_usd_price: u32) -> u32 {
        // Price expected to already be scaled
        // e.g. 1.25 == 125
        let scaling: u32 = 100u32;
        let scaled_collateral: u32 = collateral * scaling;
        let collateral_usd_vale: u32 = util_multiply(scaled_collateral, collateral_usd_price, scaling);
        
        let scaled_issued: u32 = issued * 100u32;
        return util_divide(scaled_collateral, scaled_issued, scaling);
    }

    ///////////////////////////////////////////////
    // 'Borrowed' from https://github.com/zeroknowledgetutorials/leo-fixed-point-numbers/blob/main/src/main.leo

    function util_multiply(a: u32, b: u32, s: u32) -> u32 {
        let result: u32 = a * b / s;
        return result;
    }

    function util_divide(a: u32, b: u32, s: u32) -> u32 {
        let result: u32 = s * a / b;
        return result;
    }
}
