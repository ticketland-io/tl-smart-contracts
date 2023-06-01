#[test_only]
module ticketland::secondary_market_cancel_listing_test {
  use sui::test_scenario::{
    begin, ctx, next_tx, end, take_shared, return_shared,
  };
  use ticketland::ticket::{CNT};
  use ticketland::usdc::{USDC};
  use ticketland::secondary_market_list_test::{list_cnt};
  use ticketland::secondary_market::{Listing, cancel_listing, is_listing_open};

  #[test(buyer=@0xf1)]
  fun test_cancel_listing(buyer: address) {
    list_cnt(buyer);
    let scenario_buyer = begin(buyer);
    let cnt = take_shared<CNT>(&mut scenario_buyer);
    let listing = take_shared<Listing<USDC>>(&mut scenario_buyer);
    assert!(is_listing_open(&listing), 1);

    cancel_listing<USDC>(&cnt, &mut listing, ctx(&mut scenario_buyer));
    return_shared(listing);
    next_tx(&mut scenario_buyer, buyer);

    let listing = take_shared<Listing<USDC>>(&mut scenario_buyer);
    assert!(!is_listing_open(&listing), 1);
    return_shared(listing);

    return_shared(cnt);
    end(scenario_buyer);
  }
}
