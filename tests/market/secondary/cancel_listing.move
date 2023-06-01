#[test_only]
module ticketland::secondary_market_cancel_listing_test {
  use sui::test_scenario::{
    begin, ctx, next_tx, end, take_shared, return_shared,
  };
  use ticketland::usdc::{USDC};
  use ticketland::secondary_market_list_test::{list_cnt};
  use ticketland::secondary_market::{Listing, cancel_listing, is_listing_open};

  #[test(seller=@0xf1)]
  fun test_cancel_listing(seller: address) {
    list_cnt(seller);
    let scenario_seller = begin(seller);
    let listing = take_shared<Listing<USDC>>(&mut scenario_seller);
    assert!(is_listing_open(&listing), 1);

    cancel_listing<USDC>(&mut listing, ctx(&mut scenario_seller));
    return_shared(listing);
    next_tx(&mut scenario_seller, seller);

    let listing = take_shared<Listing<USDC>>(&mut scenario_seller);
    assert!(!is_listing_open(&listing), 1);
    return_shared(listing);

    end(scenario_seller);
  }

  #[test(seller=@0xf1, chunk=@0xd0d)]
  #[expected_failure(abort_code = 0x3, location = ticketland::secondary_market)]
  fun test_should_fail_if_not_listing_owner(seller: address, chunk: address) {
    list_cnt(seller);
    let scenario_chunk = begin(chunk);
    let listing = take_shared<Listing<USDC>>(&mut scenario_chunk);

    cancel_listing<USDC>( &mut listing, ctx(&mut scenario_chunk));
  
    return_shared(listing);
    end(scenario_chunk);
  }
}
