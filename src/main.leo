// High level design
// [x] Supply asset collateral to vault for address
// [x] borrow token (up to health factor) for address
// [x] Repay token and interest
// [x] Interest paid to protocol safety fund on redemption
// [x] Health factor based liquidations by anyone
//     [x] Earn part of safety fund
//     [x] loan amount / all loan amounts => fractional share of safety fund
//     [ ] scaling factor based on health factor ?
//     [x] Incentivise others to liquidate loan
//
// [ ] Use the aleoswap pool price for reference
// [x] Work out how token transfer / ownership works
// [x] Work out how a program can 'own' funds
// [x] Have a store of balance of tokens for address so it can be transferred - has to be different from loan amounts for maths

// The 'leotoken' program.
program leotoken.aleo {
    // Mapping of supplied collateral balances for addresses
    mapping collateral_balances: address => u32;
    // Mapping of issued tokens against collateral
    mapping issued_amount: address => u32;
    // Mapping of LEOTokens for each address
    mapping balances: address => u32;

    // LEO stable token
    // - 'owner'  : The address of the account that owns the record associated with this token.
    // - 'amount' : The amount of tokens
    record Token {
        owner: address,
        amount: u32,
    }

    //////////////////////////////////////////////////////////
    // transfer
    //
    // Tranfer LEOTokens from address to address
    transition transfer(token: Token, amount: u32, destination: address) {
        // Only the owner can transfer their funds
        assert_eq(token.owner, self.caller);
        return finalize(token, amount, destination);
    }

    finalize transfer(token: Token, amount: u32, destination: address) {
        let current_amount_sender: u32 = Mapping::get_or_use(balances, token.owner, 0u32);
        Mapping::set(balances, token.owner, current_amount_sender - amount);
        let current_amount_recv: u32 = Mapping::get_or_use(balances, destination, 0u32);
        Mapping::set(balances, token.owner, current_amount_recv + amount);
    }

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
        // LEOToken amounts
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

        // Add newly minted tokens to address balance
        let address_balance: u32 = Mapping::get_or_use(balances, recipient, 0u32);
        Mapping::set(balances, recipient, address_balance + amount);
    }

    //////////////////////////////////////////////////////////
    // burn_token
    //
    // Return minted tokens to burn supply and unlock collateral
    transition burn_token(recipient: address, amount: u32, period: u32) -> Token {
        return finalize(recipient, amount, period);
    }

    finalize burn_token(recipient: address, amount: u32, period: u32) {
        let collateral_supplied: u32 = Mapping::get_or_use(collateral_balances, recipient, 0u32);
        let loaned: u32 = Mapping::get_or_use(issued_amount, recipient, 0u32);

        // Can't repay more than has been loaned, this makes no sense
        assert_eq(amount <= loaned, true);
        // Can't repay if nothing has been loaned
        assert_eq(loaned > 0u32, true);

        let address_balance: u32 = Mapping::get_or_use(balances, recipient, 0u32);
        // Can't burn more than available
        assert_eq(amount > address_balance, true);
       
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

        // Reduce the amount of tokens availble
        Mapping::set(balances, recipient, address_balance - amount);
    }

    //////////////////////////////////////////////////////////
    // liquidate_position
    //
    // If a position falls below the health factor it can be liquidated by anyone
    transition liquidate_position(liquidator: address, amount: u32, liquidatee: address) -> Token { 
        return finalize(liquidator, amount, liquidatee);
    }

    finalize liquidate_position(liquidator: address, amount: u32, liquidatee: address) {
        // First verify that the health factor of the loan has breached the risk threshold
        let collateral_supplied_liquidatee: u32 = Mapping::get_or_use(collateral_balances, liquidatee, 0u32);
        let loaned_liquidatee : u32 = Mapping::get_or_use(issued_amount, liquidatee, 0u32);

        let current_price: u32 = get_collateral_price();

        let scaling: u32 = 100u32;
        let scaled_collateral_supplied_liquidatee: u32 = collateral_supplied_liquidatee * scaling;
        let scaled_loaned_liquidatee: u32 = loaned_liquidatee * scaling;

        let health_factor: u32 = calc_health_factor(scaled_collateral_supplied_liquidatee, scaled_loaned_liquidatee, current_price);
        // Check that the health factor of loan has fallen below liquidation threshold
        assert_eq(health_factor < get_min_health_factor(), true);
        // Make sure the amount being offered is sufficient to repay the loan
        assert_eq(loaned_liquidatee, amount);

        let balance_liquidator : u32 = Mapping::get_or_use(balances, liquidator, 0u32);
        // Check the liquidator actually has the tokens to pay
        assert_eq(balance_liquidator >= amount, true);

        // Calculate reward from security fund
        let collateral_security_fund: u32 = Mapping::get_or_use(collateral_balances, get_treasury_address(), 0u32);
        let scaled_collateral_security_fund: u32 = collateral_security_fund * scaling;
        
        // get reward which is 10% of the current treasury
        let scaled_collateral_reward: u32 = util_divide(collateral_security_fund, 10u32, scaling);
        let collateral_reward: u32 = scaled_collateral_reward / scaling;

        // Liquidate the loan
        let collateral_supplied_liquidator: u32 = Mapping::get_or_use(collateral_balances, liquidator, 0u32);

        // liquidator (person initiating the liquidation) gains the collateral
        Mapping::set(collateral_balances, liquidator, collateral_supplied_liquidator + collateral_supplied_liquidatee + collateral_reward);
        // liquidatee (person being liquidated) loses their collateral
        Mapping::set(collateral_balances, liquidatee, 0u32);
        // reduce fund by reward that has been paid
        Mapping::set(collateral_balances, get_treasury_address(), collateral_security_fund - collateral_reward);
        
        // liquidator (person initiating the liquidation) sends the tokens to repay the debt
        Mapping::set(balances, liquidator, balance_liquidator - amount);
        // IMPROVEMENT: liquidatee (person being liquidated) loses their tokens (if they still have them) and these are used for (partial?) payment of the loan
        // loan now repaid for liqudatee
        Mapping::set(issued_amount, liquidatee, 0u32);
    }

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
        let scaled_rate_per_period: u32 = util_divide(get_periods_in_year() * scaling, get_interest_apy(), scaling);

        // TODO: how can this be better, this enforces an upper limit
        // and results in a useless number of cycles
        for i:u32 in 0u32..3000u32 {
            if i < periods {
                scaled_interest_amount += util_multiply(scaled_interest_amount, scaled_rate_per_period, scaling);
            }
        }

        // TODO test maths
        return scaled_interest_amount;
    }

    inline get_collateral_price() -> u32 {
        // TODO actually look up based on the token
        // TODO currently returning a static price 2.25 TOKEN == 1 USD
        return 225u32;
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
