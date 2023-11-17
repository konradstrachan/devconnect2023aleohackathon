// High level design
// [ ] Supply asset collateral to vault for address
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
    transition main(public a: u32, b: u32) -> u32 {
        let c: u32 = a + b;
        return c;
    }
}
