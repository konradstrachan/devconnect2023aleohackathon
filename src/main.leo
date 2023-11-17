// High level design
// [x] Supply asset collateral to vault for address
// [x] borrow token (up to health factor) for address
// [x] Repay token and interest
// [x] Interest paid to protocol safety fund on redemption
// [ ] Health factor based liquidations by anyone
//     [ ] Earn part of safety fund
//     [ ] loan amount / all loan amounts => fractional share of safety fund
//     [ ] scaling factor based on health factor ?
//     [ ] Incentivise others to liquidate loan
//
// [ ] Use the aleoswap pool price for reference
// [ ] Work out how token transfer / ownership works
// [ ] Work out how a program can 'own' funds
//

// The 'leotoken' program.
program leotoken.aleo {
    // Mapping of supplied collateral balances for addresses
    mapping collateral_balances: address => u32;
    // Mapping of issues tokens against collateral
    mapping issued_amount: address => u32;

    // LEO stable token
    // - 'owner'  : The address of the account that owns the record associated with this token.
    // - 'amount' : The amount of tokens owned by the account.
    // TODO store interest rate and starting time to work out interest?
    record Token {
        owner: address,
        amount: u32,
    }

    // Security treasury for storing fees generated from loaded tokens
    // Used to incentivise the repayment of other loans that fall
    // below the safe health score
    /*record Treasury {
        owner: address,
        amount: u32,
    }*/

    //////////////////////////////////////////////////////////
    // deposit_collateral
    //
    // Deposit collateral which can then be borrowed against
    // Improvements : multitoken collateral
    transition deposit_collateral(token: Token, amount: u32) -> Token {
        let difference: u32 = token.amount - amount;

        let remaining: Token = Token {
            owner: token.owner,
            amount: difference,
        };

        return remaining then finalize(token.owner, amount);
    }

    finalize deposit_collateral(depositor: address, amount: u32) {
        let current_amount: u32 = Mapping::get_or_use(collateral_balances, depositor, 0u32);
        Mapping::set(collateral_balances, depositor, current_amount + amount);
    }

    //////////////////////////////////////////////////////////
    // withdraw_collateral
    //
    // Withdrawl collateral that was used to borrow against
    transition withdraw_collateral(recipient: address, amount: u32) -> Token {
        let token: Token = Token {
            owner: recipient,
            amount: amount,
        };
        return token then finalize(recipient, amount);
    }

    finalize withdraw_collateral(recipient: address, amount: u32) {
        let collateral_supplied: u32 = Mapping::get_or_use(collateral_balances, recipient, 0u32);
        let loaned: u32 = Mapping::get_or_use(issued_amount, recipient, 0u32);
        
        let current_price: u32 = get_collateral_price();

        let scaling: u32 = 100u32;
        // Get remaining collateral if withdrawal allowed
        let scaled_remaining_collateral: u32 = (collateral_supplied - amount) * scaling;
        let scaled_loaned: u32 = loaned * scaling;

        let health_factor: u32 = calc_health_factor(scaled_remaining_collateral, scaled_loaned, current_price);

        // Check that it will not violate health factor of loan
        assert_eq(health_factor >= get_min_health_factor(), true);
        Mapping::set(collateral_balances, recipient, collateral_supplied - amount);
    }

    //////////////////////////////////////////////////////////
    // mint_token
    //
    // Mint tokens against the collateral supplied
    transition mint_token(recipient: address, amount: u32) -> Token {
        let token: Token = Token {
            owner: recipient,
            amount: amount,
        };
        return token then finalize(recipient, amount);
    }

    finalize mint_token(recipient: address, amount: u32) {
        let collateral_supplied: u32 = Mapping::get_or_use(collateral_balances, recipient, 0u32);
        let loaned: u32 = Mapping::get_or_use(issued_amount, recipient, 0u32);
        
        let current_price: u32 = get_collateral_price();

        let scaling: u32 = 100u32;
        let scaled_collateral: u32 = collateral_supplied * scaling;
        let scaled_proposed_loaned: u32 = (loaned + amount) * scaling;

        let health_factor: u32 = calc_health_factor(scaled_collateral,scaled_proposed_loaned, current_price);

        // Check that it will not violate health factor of loan
        assert_eq(health_factor >= get_min_health_factor(), true);
        Mapping::set(issued_amount, recipient, loaned + amount);
    }

    //////////////////////////////////////////////////////////
    // burn_token
    //
    // Return minted tokens to burn supply and unlock collateral
    transition burn_token(recipient: address, amount: u32, period: u32) -> Token {
        let token: Token = Token {
            owner: recipient,
            amount: amount,
        };
        return token then finalize(recipient, amount, period);
    }

    finalize burn_token(recipient: address, amount: u32, period: u32) {
        let collateral_supplied: u32 = Mapping::get_or_use(collateral_balances, recipient, 0u32);
        let loaned: u32 = Mapping::get_or_use(issued_amount, recipient, 0u32);

        // Can't repay more than has been loaned, this makes no sense
        assert_eq(amount <= loaned, true);
        // Can't repay if nothing has been loaned
        assert_eq(loaned > 0u32, true);
        
        let current_price: u32 = get_collateral_price();

        let scaling: u32 = 100u32;
        let scaled_collateral: u32 = collateral_supplied * scaling;
        let scaled_proposed_loaned: u32 = (loaned + amount) * scaling;

        let health_factor: u32 = calc_health_factor(scaled_collateral,scaled_proposed_loaned, current_price);
        // Check that it will not violate health factor of loan
        assert_eq(health_factor >= get_min_health_factor(), true);

        // Calculate the fee paid to the treasury
        // This is done by how long the loan has been open * interest rate
        let scaled_interest_accumulated u32: = get_interest_accumulated(collateral_supplied, period);
        let interest_accumulated u32: = scaled_interest_accumulated / 100u32;

        // Reduce collateral accordingly taking the fee
        Mapping::set(collateral_balances, recipient, collateral_supplied - interest_accumulated);
        
        // Send interest to the treasury
        let treasury_balance: u32 = Mapping::get_or_use(collateral_balances, get_treasury_address(), 0u32);
        treasury_balance += interest_accumulated;
        Mapping::set(collateral_balances, get_treasury_address(), treasury_balance);
        
        // Reduce amount of issued tokens
        Mapping::set(issued_amount, recipient, loaned - amount);

        // TODO recalc health factor now?
        // TODO what happens if as a result of burning and repaying the new health factor is too low?
    }

    //////////////////////////////////////////////////////////
    // liquidate_position
    //
    // 
    
    // TODO

    //////////////////////////////////////////////////////////
    // 
    // Inline helpers
    // 

    inline calc_health_factor(collateral: u32, issued: u32, collateral_usd_price: u32) -> u32 {
        if (issued == 0u32) {
            // If no tokens have been issued against the collateral, there
            // is no need to check what the health factor is as it will always pass
            return get_min_health_factor() + 1u32;
        }

        // Price expected to already be scaled
        // e.g. 1.25 == 125
        let scaling: u32 = 100u32;
        let scaled_collateral: u32 = collateral * scaling;
        let collateral_usd_vale: u32 = util_multiply(scaled_collateral, collateral_usd_price, scaling);
        
        let scaled_issued: u32 = issued * 100u32;
        let health_factor: u32 = util_divide(scaled_collateral, scaled_issued, scaling);
        return health_factor;
    }

    inline get_interest_accumulated(loan: u32, periods: u32) -> u32 {
        let scaling: u32 = 100u32;

        let scaled_interest_amount: u32 = loan * scaling;
        let scaled_rate_per_period: u32 = util_divide(get_periods_in_year() * scaling, get_interest_apy() * scaling, scaling);

        // TODO: how can this be better, this enforces an upper limit
        // and results in a useless number of cycles
        for i:u32 in 0u32..3000u32 {
            if i < periods {
                scaled_interest_amount += util_multiply(scaled_interest_amount, scaled_rate_per_period, scaling);
            }
        }

        return scaled_interest_amount;
    }

    inline get_collateral_price() -> u32 {
        // TODO actually look up based on the token
        // TODO currently returning a static price 1.25 TOKEN == 1 USD
        return 125u32;
    }

    inline get_min_health_factor() -> u32 {
        // 125% overcollateralisation required
        return 125u32;
    }

    inline get_interest_apy() -> u32 {
        // 5% APY (0.05)
        return 5u32;
    }

    inline get_periods_in_year() -> u32 {
        // A period of interest accumulation is defined as a single day
        return 365u32;
    }

    inline get_treasury_address() -> address {
        // TODO set actual address
        return aleo1t0uer3jgtsgmx5tq6x6f9ecu8tr57rzzfnc2dgmcqldceal0ls9qf6st7a;
    }

    ///////////////////////////////////////////////
    // 
    // 'Borrowed' from https://github.com/zeroknowledgetutorials/leo-fixed-point-numbers/blob/main/src/main.leo
    // 

    inline util_multiply(a: u32, b: u32, s: u32) -> u32 {
        let result: u32 = a * b / s;
        return result;
    }

    inline util_divide(a: u32, b: u32, s: u32) -> u32 {
        let result: u32 = s * a / b;
        return result;
    }
    
    transition main(public a: u32, b: u32) -> u32 {
        let c: u32 = a + b;
        return c;
    }
}
