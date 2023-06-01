#[test_only]
module ticketland::fixed_price_sale_test {
  use sui::clock::{Self, Clock, increment_for_testing};
  use std::string::{utf8};
  use sui::coin::{Self, Coin, mint_for_testing, burn_for_testing};
  use sui::sui::SUI;
  use sui::test_scenario::{
    Scenario, begin, ctx, next_tx, end, take_from_sender, return_to_sender, 
    take_shared, return_shared, take_from_address,
  };
  use ticketland::merkle_tree_test::{Tree, get_proof};
  use ticketland::usdc::{USDC};
  use ticketland::ticket::{CNT, get_cnt_owner};
  use ticketland::event_registry::{Config, drop_config};
  use ticketland::event_test::{create_new_event, create_new_config, setup_ticket_types};
  use ticketland::event::{Event, EventOrganizerCap, test_init};
  use ticketland::primary_market::{fixed_price};
  use ticketland::common_test::{to_base};

  fun setup(scenario: &mut Scenario, clock: &Clock): (Event, Config, Tree) {
    test_init(ctx(scenario));
    create_new_event(scenario);
    next_tx(scenario, @admin);
    let event = take_shared<Event>(scenario);
    let organizer_cap = take_from_sender<EventOrganizerCap>(scenario);
    
    let (_, tree_2, _) = setup_ticket_types(
      scenario,
      &organizer_cap,
      clock,
      &mut event,
    );
    let config = create_new_config(scenario);
    
    next_tx(scenario, @admin);
    return_to_sender(scenario, organizer_cap);

    (event, config, tree_2)
  }

  public fun fixed_price_purchase(buyer: address) {
    let scenario = begin(@admin);
    let clock = clock::create_for_testing(ctx(&mut scenario));
    let (event, config, tree_2) = setup(&mut scenario, &clock);
    let scenario_buyer = begin(buyer);
    let proof = get_proof(&tree_2, 25);
    increment_for_testing(&mut clock, 10);
    let usdc_coins = mint_for_testing<USDC>(to_base(100_000), ctx(&mut scenario_buyer));
    next_tx(&mut scenario_buyer, buyer);

    fixed_price(
      &mut event,
      &mut usdc_coins,
      1,
      utf8(b"Paid Ticket"),
      25,
      utf8(b"25"),
      proof,
      &config,
      &clock,
      ctx(&mut scenario_buyer),
    );
    
    next_tx(&mut scenario_buyer, buyer);

    // A shared CNT object is created
    let cnt = take_shared<CNT>(&mut scenario_buyer);
    assert!(get_cnt_owner(&cnt) == buyer, 1);

    // Fees should be sent to protocol recipient 5% of 100 USDC price
    let coins = take_from_address<Coin<USDC>>(&mut scenario_buyer, @protocol_fee_address);
    assert!(coin::value(&coins) == to_base(5), 1);
    burn_for_testing(coins);

    // Price minus fees should be sent to the event organizer (in our case it's admin)
    let coins = take_from_address<Coin<USDC>>(&mut scenario_buyer, @admin);
    assert!(coin::value(&coins) == to_base(95), 1);
    burn_for_testing(coins);

    drop_config(config);
    return_shared(event);
    return_shared(cnt);
    burn_for_testing(usdc_coins);
    clock::destroy_for_testing(clock);
    end(scenario);
    end(scenario_buyer);
  }

  #[test(buyer=@0xf1)]
  fun test_sale_should_mint_cnt(buyer: address) {
    fixed_price_purchase(buyer)
  }

  #[test(buyer=@0xf1)]
  #[expected_failure(abort_code = 0x0, location = ticketland::market_utils)]
  fun test_should_fail_if_low_balance(buyer: address) {
    let scenario = begin(@admin);
    let clock = clock::create_for_testing(ctx(&mut scenario));
    let (event, config, tree_2) = setup(&mut scenario, &clock);
    let scenario_buyer = begin(buyer);
    increment_for_testing(&mut clock, 10);
    let proof = get_proof(&tree_2, 25);
    let usdc_coins = mint_for_testing<USDC>(to_base(99), ctx(&mut scenario_buyer));
    next_tx(&mut scenario_buyer, buyer);

    fixed_price(
      &mut event,
      &mut usdc_coins,
      1,
      utf8(b"Paid Ticket"),
      25,
      utf8(b"25"),
      proof,
      &config,
      &clock,
      ctx(&mut scenario_buyer),
    );
    
    drop_config(config);
    return_shared(event);
    burn_for_testing(usdc_coins);
    clock::destroy_for_testing(clock);
    end(scenario);
    end(scenario_buyer);
  }

  #[test(buyer=@0xf1)]
  #[expected_failure(abort_code = 0x2, location = sui::dynamic_field)]
  fun test_should_fail_if_wrong(buyer: address) {
    let scenario = begin(@admin);
    let clock = clock::create_for_testing(ctx(&mut scenario));
    let (event, config, tree_2) = setup(&mut scenario, &clock);
    let scenario_buyer = begin(buyer);
    increment_for_testing(&mut clock, 10);
    let proof = get_proof(&tree_2, 25);
    // Ticket type 0 has a fixed price sale type that accepts USDC not SUI
    let sui_coint = mint_for_testing<SUI>(to_base(100), ctx(&mut scenario_buyer));
    next_tx(&mut scenario_buyer, buyer);

    fixed_price(
      &mut event,
      &mut sui_coint,
      1,
      utf8(b"Paid Ticket"),
      25,
      utf8(b"25"),
      proof,
      &config,
      &clock,
      ctx(&mut scenario_buyer),
    );
    
    drop_config(config);
    return_shared(event);
    burn_for_testing(sui_coint);
    clock::destroy_for_testing(clock);
    end(scenario);
    end(scenario_buyer);
  }

  #[test(buyer=@0xf1)]
  #[expected_failure(abort_code = 0x0, location = ticketland::primary_market)]
  fun test_should_fail_if_sale_not_open(buyer: address) {
    let scenario = begin(@admin);
    let clock = clock::create_for_testing(ctx(&mut scenario));
    let (event, config, tree_2) = setup(&mut scenario, &clock);
    let scenario_buyer = begin(buyer);
    let proof = get_proof(&tree_2, 25);
    let usdc_coins = mint_for_testing<USDC>(to_base(100_000), ctx(&mut scenario_buyer));
    next_tx(&mut scenario_buyer, buyer);

    fixed_price(
      &mut event,
      &mut usdc_coins,
      1,
      utf8(b"Paid Ticket"),
      25,
      utf8(b"25"),
      proof,
      &config,
      &clock,
      ctx(&mut scenario_buyer),
    );
    
    drop_config(config);
    return_shared(event);
    burn_for_testing(usdc_coins);
    clock::destroy_for_testing(clock);
    end(scenario);
    end(scenario_buyer);
  }

  #[test(buyer=@0xf1)]
  #[expected_failure(abort_code = 0x0, location = ticketland::primary_market)]
  fun test_should_fail_if_sale_not_closed(buyer: address) {
    let scenario = begin(@admin);
    let clock = clock::create_for_testing(ctx(&mut scenario));
    let (event, config, tree_2) = setup(&mut scenario, &clock);
    let scenario_buyer = begin(buyer);
    let proof = get_proof(&tree_2, 25);
    let usdc_coins = mint_for_testing<USDC>(to_base(100_000), ctx(&mut scenario_buyer));
    increment_for_testing(&mut clock, 21); // end of sale
    next_tx(&mut scenario_buyer, buyer);

    fixed_price(
      &mut event,
      &mut usdc_coins,
      1,
      utf8(b"Paid Ticket"),
      25,
      utf8(b"25"),
      proof,
      &config,
      &clock,
      ctx(&mut scenario_buyer),
    );
    
    drop_config(config);
    return_shared(event);
    burn_for_testing(usdc_coins);
    clock::destroy_for_testing(clock);
    end(scenario);
    end(scenario_buyer);
  }

  #[test(buyer=@0xf1)]
  #[expected_failure(abort_code = 0x1, location = ticketland::primary_market)]
  fun test_should_fail_if_seat_index_does_to_belong_ticket_type(buyer: address) {
    let scenario = begin(@admin);
    let clock = clock::create_for_testing(ctx(&mut scenario));
    let (event, config, tree_2) = setup(&mut scenario, &clock);
    let scenario_buyer = begin(buyer);
    let proof = get_proof(&tree_2, 25);
    let usdc_coins = mint_for_testing<USDC>(to_base(100_000), ctx(&mut scenario_buyer));
    increment_for_testing(&mut clock, 10); // end of sale
    next_tx(&mut scenario_buyer, buyer);

    fixed_price(
      &mut event,
      &mut usdc_coins,
      0, // ticket type index
      utf8(b"Paid Ticket"),
      25, // seat index does not belong to ticket type index
      utf8(b"25"),
      proof,
      &config,
      &clock,
      ctx(&mut scenario_buyer),
    );
    
    drop_config(config);
    return_shared(event);
    burn_for_testing(usdc_coins);
    clock::destroy_for_testing(clock);
    end(scenario);
    end(scenario_buyer);
  }

  #[test(buyer=@0xf1)]
  #[expected_failure(abort_code = 0x2, location = ticketland::primary_market)]
  fun test_should_fail_if_seat_not_available(buyer: address) {
    let scenario = begin(@admin);
    let clock = clock::create_for_testing(ctx(&mut scenario));
    let (event, config, tree_2) = setup(&mut scenario, &clock);
    let scenario_buyer = begin(buyer);
    let proof = get_proof(&tree_2, 25);
    increment_for_testing(&mut clock, 10);
    let usdc_coins = mint_for_testing<USDC>(to_base(100_000), ctx(&mut scenario_buyer));
    next_tx(&mut scenario_buyer, buyer);

    fixed_price(
      &mut event,
      &mut usdc_coins,
      1,
      utf8(b"Paid Ticket"),
      25,
      utf8(b"25"),
      proof,
      &config,
      &clock,
      ctx(&mut scenario_buyer),
    );

    next_tx(&mut scenario_buyer, buyer);

    // try to buy the same ticket
    fixed_price(
      &mut event,
      &mut usdc_coins,
      1,
      utf8(b"Paid Ticket"),
      25,
      utf8(b"25"),
      proof,
      &config,
      &clock,
      ctx(&mut scenario_buyer),
    );
    
    drop_config(config);
    return_shared(event);
    burn_for_testing(usdc_coins);
    clock::destroy_for_testing(clock);
    end(scenario);
    end(scenario_buyer);
  }
}
