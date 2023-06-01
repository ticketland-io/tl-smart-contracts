#[test_only]
module ticketland::secondary_market_purchase_listing_test {
  use sui::test_scenario::{
    begin, ctx, next_tx, end, take_shared, return_shared, take_from_address,
    new_object,
  };
  use sui::coin::{Coin, value, mint_for_testing, burn_for_testing};
  use sui::object::{Self, uid_to_address};
  use ticketland::usdc::{USDC};
  use ticketland::ticket::{CNT, get_cnt_owner, create_cnt_for_testing};
  use ticketland::event_test::{create_new_config};
  use ticketland::secondary_market_list_test::{list_cnt};
  use ticketland::event::{Event, get_event_id};
  use ticketland::secondary_market::{Listing, purchase_listing, is_listing_open, cancel_listing};
  use ticketland::common_test::{to_base};

  #[test(seller=@0xf1, buyer=@0xf2)]
  fun test_purchase_listing(seller: address, buyer: address) {
    list_cnt(seller);

    let scenario_buyer = begin(buyer);
    let scenario_seller = begin(seller);
    let cnt = take_shared<CNT>(&mut scenario_buyer);
    let listing = take_shared<Listing<USDC>>(&mut scenario_buyer);
    assert!(get_cnt_owner(&cnt) == seller, 1);
    assert!(is_listing_open(&listing), 1);
    
    let config = create_new_config(&mut scenario_buyer);
    next_tx(&mut scenario_buyer, buyer);

    let usdc_coins = mint_for_testing<USDC>(to_base(110), ctx(&mut scenario_buyer));
    next_tx(&mut scenario_buyer, buyer);

    purchase_listing<USDC>(&mut cnt, &mut listing, &mut usdc_coins, &config, ctx(&mut scenario_buyer));
    return_shared(listing);
    next_tx(&mut scenario_buyer, buyer);

    // listing is closed
    let listing = take_shared<Listing<USDC>>(&mut scenario_buyer);
    assert!(!is_listing_open(&listing), 1);
    return_shared(listing);

    // Fees should be sent to protocol recipient 5% of 110 USDC price
    let coins = take_from_address<Coin<USDC>>(&mut scenario_buyer, @protocol_fee_address);
    assert!(value(&coins) == 550000000, 1);
    burn_for_testing(coins);

    // funds are tranferred to protocol
    let coins = take_from_address<Coin<USDC>>(&mut scenario_seller, seller);
    assert!(value(&coins) == 10450000000, 1);
    burn_for_testing(coins);

    // ticket ownership is changed 
    assert!(get_cnt_owner(&cnt) == buyer, 1);
    
    burn_for_testing(usdc_coins);
    return_shared(cnt);
    return_shared(config);
    end(scenario_buyer);
    end(scenario_seller);
  }
  
  #[test(seller=@0xf1, buyer=@0xf2)]
  #[expected_failure(abort_code = 0x2, location = ticketland::secondary_market)]
  fun test_fail_if_wrong_cnt_provided(seller: address, buyer: address) {
    let scenario_buyer = begin(buyer);
    let scenario_seller = begin(seller);
  
    list_cnt(seller);

    let event = take_shared<Event>(&mut scenario_seller);
    let ticket_type_id = new_object(&mut scenario_seller);
    let wrong_cnt = create_cnt_for_testing(
      seller,
      get_event_id(&event),
      uid_to_address(&ticket_type_id),
      ctx(&mut scenario_seller),
    );
  
    object::delete(ticket_type_id);
    let listing = take_shared<Listing<USDC>>(&mut scenario_buyer);
    let config = create_new_config(&mut scenario_buyer);

    let usdc_coins = mint_for_testing<USDC>(to_base(110), ctx(&mut scenario_buyer));
    next_tx(&mut scenario_buyer, buyer);
  
    // create another cnt
    purchase_listing<USDC>(&mut wrong_cnt, &mut listing, &mut usdc_coins, &config, ctx(&mut scenario_buyer));
    
    burn_for_testing(usdc_coins);
    return_shared(wrong_cnt);
    return_shared(config);
    return_shared(listing);
    return_shared(event);
    end(scenario_buyer);
    end(scenario_seller); 
  }

  #[test(seller=@0xf1, buyer=@0xf2)]
  #[expected_failure(abort_code = 0x8, location = ticketland::secondary_market)]
  fun test_fail_if_listing_closed(seller: address, buyer: address) {
    list_cnt(seller);

    let scenario_buyer = begin(buyer);
    let scenario_seller = begin(seller);
    let cnt = take_shared<CNT>(&mut scenario_buyer);
    let listing = take_shared<Listing<USDC>>(&mut scenario_buyer);
    let config = create_new_config(&mut scenario_buyer);
    let usdc_coins = mint_for_testing<USDC>(to_base(110), ctx(&mut scenario_buyer));
    next_tx(&mut scenario_buyer, buyer);

    // try to purchase a canceled listing
    cancel_listing<USDC>(&mut listing, ctx(&mut scenario_seller));
    purchase_listing<USDC>(&mut cnt, &mut listing, &mut usdc_coins, &config, ctx(&mut scenario_buyer));

    burn_for_testing(usdc_coins);
    return_shared(cnt);
    return_shared(listing);
    return_shared(config);
    end(scenario_buyer);
    end(scenario_seller);
  }
}
