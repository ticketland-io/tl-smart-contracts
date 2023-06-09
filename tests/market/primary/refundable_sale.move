#[test_only]
module ticketland::refunable_sale_test {
  use sui::clock::{Self, Clock, increment_for_testing};
  use std::string::{utf8};
  use sui::coin::{Self, Coin, mint_for_testing, burn_for_testing};
  use sui::sui::SUI;
  use sui::test_scenario::{
    Scenario, begin, ctx, next_tx, end, take_from_sender, return_to_sender, 
    take_shared, return_shared,
  };
  use ticketland::merkle_tree_test::{Tree, get_proof};
  use ticketland::usdc::{USDC};
  use ticketland::ticket::{CNT, get_cnt_id, get_cnt_owner};
  use ticketland::event_test::{create_new_event, setup_ticket_types};
  use ticketland::event::{Event, EventOrganizerCap, test_init};
  use ticketland::attendance::{create_config, drop_config, set_attended_for_testing};
  use ticketland::primary_market::{refundable};
  use ticketland::basic_sale::{Refund, get_refund_info, claim_refund};
  use ticketland::common_test::{to_base};

  fun setup(scenario: &mut Scenario, clock: &Clock): (Event, Tree) {
    test_init(ctx(scenario));
    create_new_event(scenario);
    next_tx(scenario, @admin);
    let event = take_shared<Event>(scenario);
    let organizer_cap = take_from_sender<EventOrganizerCap>(scenario);
    
    let (_, _, tree_3) = setup_ticket_types(
      scenario,
      &organizer_cap,
      clock,
      &mut event,
    );
    
    next_tx(scenario, @admin);
    return_to_sender(scenario, organizer_cap);

    (event, tree_3)
  }

  fun refundable_purchase(buyer: address) {
    let scenario = begin(@admin);
    let clock = clock::create_for_testing(ctx(&mut scenario));
    let (event, tree_3) = setup(&mut scenario, &clock);
    let scenario_buyer = begin(buyer);
    let proof = get_proof(&tree_3, 80);
    increment_for_testing(&mut clock, 10);
    let sui_coins = mint_for_testing<SUI>(to_base(100_000), ctx(&mut scenario_buyer));
    next_tx(&mut scenario_buyer, buyer);

    refundable(
      &mut event,
      &mut sui_coins,
      2,
      utf8(b"Refundable Ticket"),
      80,
      utf8(b"80"),
      proof,
      &clock,
      ctx(&mut scenario_buyer),
    );
    
    next_tx(&mut scenario_buyer, buyer);

    // A shared CNT object is created
    let cnt = take_shared<CNT>(&mut scenario_buyer);
    assert!(get_cnt_owner(&cnt) == buyer, 1);
    
    // Should wrap coins in a Refund onject and send it to the buyer
    let refund = take_from_sender<Refund<SUI>>(&mut scenario_buyer);
    let (cnt_id, amount) = get_refund_info<SUI>(&refund);
    assert!(cnt_id == get_cnt_id(&cnt), 1);
    assert!(amount == to_base(50), 1);

    return_shared(event);
    return_shared(cnt);
    return_to_sender(&mut scenario_buyer, refund);
    burn_for_testing(sui_coins);
    clock::destroy_for_testing(clock);
    end(scenario);
    end(scenario_buyer);
  }

  #[test(buyer=@0xf1)]
  fun test_sale_should_mint_cnt(buyer: address) {
    refundable_purchase(buyer);
  }

  #[test(buyer=@0xf1)]
  #[expected_failure(abort_code = 0x0, location = ticketland::market_utils)]
  fun test_should_fail_if_low_balance(buyer: address) {
    let scenario = begin(@admin);
    let clock = clock::create_for_testing(ctx(&mut scenario));
    let (event, tree_3) = setup(&mut scenario, &clock);
    let scenario_buyer = begin(buyer);
    let proof = get_proof(&tree_3, 80);
    increment_for_testing(&mut clock, 10);
    let sui_coins = mint_for_testing<SUI>(to_base(49), ctx(&mut scenario_buyer));
    next_tx(&mut scenario_buyer, buyer);

    refundable(
      &mut event,
      &mut sui_coins,
      2,
      utf8(b"Refundable Ticket"),
      80,
      utf8(b"80"),
      proof,
      &clock,
      ctx(&mut scenario_buyer),
    );
    
    return_shared(event);
    burn_for_testing(sui_coins);
    clock::destroy_for_testing(clock);
    end(scenario);
    end(scenario_buyer);
  }

  #[test(buyer=@0xf1)]
  #[expected_failure(abort_code = 0x2, location = sui::dynamic_field)]
  fun test_should_fail_if_wrong(buyer: address) {
    let scenario = begin(@admin);
    let clock = clock::create_for_testing(ctx(&mut scenario));
    let (event, tree_3) = setup(&mut scenario, &clock);
    let scenario_buyer = begin(buyer);
    let proof = get_proof(&tree_3, 80);
    increment_for_testing(&mut clock, 10);
    let usdc_coins = mint_for_testing<USDC>(to_base(50), ctx(&mut scenario_buyer));
    next_tx(&mut scenario_buyer, buyer);

    refundable(
      &mut event,
      &mut usdc_coins,
      2,
      utf8(b"Refundable Ticket"),
      80,
      utf8(b"80"),
      proof,
      &clock,
      ctx(&mut scenario_buyer),
    );
    
    return_shared(event);
    burn_for_testing(usdc_coins);
    clock::destroy_for_testing(clock);
    end(scenario);
    end(scenario_buyer);
  }

  #[test(buyer=@0xf1)]
  #[expected_failure(abort_code = 0x0, location = ticketland::primary_market)]
  fun test_should_fail_if_sale_not_open(buyer: address) {
    let scenario = begin(@admin);
    let clock = clock::create_for_testing(ctx(&mut scenario));
    let (event, tree_3) = setup(&mut scenario, &clock);
    let scenario_buyer = begin(buyer);
    let proof = get_proof(&tree_3, 80);
    let sui_coins = mint_for_testing<SUI>(to_base(50), ctx(&mut scenario_buyer));
    next_tx(&mut scenario_buyer, buyer);

    refundable(
      &mut event,
      &mut sui_coins,
      2,
      utf8(b"Refundable Ticket"),
      80,
      utf8(b"80"),
      proof,
      &clock,
      ctx(&mut scenario_buyer),
    );
    
    return_shared(event);
    burn_for_testing(sui_coins);
    clock::destroy_for_testing(clock);
    end(scenario);
    end(scenario_buyer);
  }

  #[test(buyer=@0xf1)]
  #[expected_failure(abort_code = 0x0, location = ticketland::primary_market)]
  fun test_should_fail_if_sale_not_closed(buyer: address) {
    let scenario = begin(@admin);
    let clock = clock::create_for_testing(ctx(&mut scenario));
    let (event, tree_3) = setup(&mut scenario, &clock);
    let scenario_buyer = begin(buyer);
    let proof = get_proof(&tree_3, 80);
    increment_for_testing(&mut clock, 21);
    let sui_coins = mint_for_testing<SUI>(to_base(50), ctx(&mut scenario_buyer));
    next_tx(&mut scenario_buyer, buyer);

    refundable(
      &mut event,
      &mut sui_coins,
      2,
      utf8(b"Refundable Ticket"),
      80,
      utf8(b"80"),
      proof,
      &clock,
      ctx(&mut scenario_buyer),
    );
    
    return_shared(event);
    burn_for_testing(sui_coins);
    clock::destroy_for_testing(clock);
    end(scenario);
    end(scenario_buyer);
  }

  #[test(buyer=@0xf1)]
  #[expected_failure(abort_code = 0x1, location = ticketland::primary_market)]
  fun test_should_fail_if_seat_index_does_to_belong_ticket_type(buyer: address) {
    let scenario = begin(@admin);
    let clock = clock::create_for_testing(ctx(&mut scenario));
    let (event, tree_3) = setup(&mut scenario, &clock);
    let scenario_buyer = begin(buyer);
    let proof = get_proof(&tree_3, 80);
    increment_for_testing(&mut clock, 10);
    let sui_coins = mint_for_testing<SUI>(to_base(50), ctx(&mut scenario_buyer));
    next_tx(&mut scenario_buyer, buyer);

    refundable(
      &mut event,
      &mut sui_coins,
      1, // ticket type index
      utf8(b"Refundable Ticket"),
      80, // this does not belong to the ticket type 1
      utf8(b"80"),
      proof,
      &clock,
      ctx(&mut scenario_buyer),
    );
    
    return_shared(event);
    burn_for_testing(sui_coins);
    clock::destroy_for_testing(clock);
    end(scenario);
    end(scenario_buyer);
  }
  
  #[test(buyer=@0xf1)]
  #[expected_failure(abort_code = 0x2, location = ticketland::primary_market)]
  fun test_should_fail_if_seat_not_available(buyer: address) {
    let scenario = begin(@admin);
    let clock = clock::create_for_testing(ctx(&mut scenario));
    let (event, tree_3) = setup(&mut scenario, &clock);
    let scenario_buyer = begin(buyer);
    let proof = get_proof(&tree_3, 80);
    increment_for_testing(&mut clock, 10);
    let sui_coins = mint_for_testing<SUI>(to_base(100_000), ctx(&mut scenario_buyer));
    next_tx(&mut scenario_buyer, buyer);

    refundable(
      &mut event,
      &mut sui_coins,
      2,
      utf8(b"Refundable Ticket"),
      80,
      utf8(b"80"),
      proof,
      &clock,
      ctx(&mut scenario_buyer),
    );
    next_tx(&mut scenario_buyer, buyer);

    // try oto buy the same ticket again
    refundable(
      &mut event,
      &mut sui_coins,
      2,
      utf8(b"Refundable Ticket"),
      80,
      utf8(b"80"),
      proof,
      &clock,
      ctx(&mut scenario_buyer),
    );
    return_shared(event);
    burn_for_testing(sui_coins);
    clock::destroy_for_testing(clock);
    end(scenario);
    end(scenario_buyer);
  }

  #[test(buyer=@0xf1)]
  #[expected_failure(abort_code = 0x0, location = ticketland::basic_sale)]
  fun test_should_not_allow_refund_if_not_attended(buyer: address) {
    let scenario_buyer = begin(buyer);
    refundable_purchase(buyer);
    
    let cnt = take_shared<CNT>(&mut scenario_buyer);
    let refund = take_from_sender<Refund<SUI>>(&mut scenario_buyer);
    let attendance_config = create_config(ctx(&mut scenario_buyer));

    claim_refund(&cnt, &attendance_config, refund, ctx(&mut scenario_buyer));

    return_shared(cnt);
    drop_config(attendance_config);
    end(scenario_buyer);
  }

  #[test(buyer=@0xf1)]
  fun test_should_allow_refunds(buyer: address) {
    let scenario_buyer = begin(buyer);
    refundable_purchase(buyer);
    
    let cnt = take_shared<CNT>(&mut scenario_buyer);
    let refund = take_from_sender<Refund<SUI>>(&mut scenario_buyer);
    let attendance_config = create_config(ctx(&mut scenario_buyer));

    set_attended_for_testing(&cnt, &mut attendance_config);
    claim_refund(&cnt, &attendance_config, refund, ctx(&mut scenario_buyer));
    next_tx(&mut scenario_buyer, buyer);

    // coins are returned to the buyer
    let refund_coins = take_from_sender<Coin<SUI>>(&mut scenario_buyer);
    assert!(coin::value(&refund_coins) == to_base(50), 1);

    return_shared(cnt);
    burn_for_testing(refund_coins);
    drop_config(attendance_config);
    end(scenario_buyer);
  }
}
