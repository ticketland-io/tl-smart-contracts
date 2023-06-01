#[test_only]
module ticketland::free_sale_test {
  use sui::clock::{Self, Clock, increment_for_testing};
  use std::string::{utf8};
  use ticketland::merkle_tree_test::{Tree, get_proof};
  use ticketland::ticket::{CNT};
  use sui::test_scenario::{
    Scenario, begin, ctx, next_tx, end, take_from_sender, return_to_sender, 
    take_shared, return_shared,
  };
  use ticketland::event_test::{create_new_event, setup_ticket_types};
  use ticketland::event::{Event, EventOrganizerCap, test_init, get_available_seats};
  use ticketland::primary_market::{free_sale};

  fun setup(scenario: &mut Scenario, clock: &Clock): (Event, Tree) {
    test_init(ctx(scenario));
    create_new_event(scenario);
    next_tx(scenario, @admin);
    let event = take_shared<Event>(scenario);
    let organizer_cap = take_from_sender<EventOrganizerCap>(scenario);
    
    let (tree_1, _, _) = setup_ticket_types(
      scenario,
      &organizer_cap,
      clock,
      &mut event,
    );

    next_tx(scenario, @admin);
    return_to_sender(scenario, organizer_cap);

    (event, tree_1)
  }

  public fun free_purchase(buyer: address) {
    let scenario = begin(@admin);
    let clock = clock::create_for_testing(ctx(&mut scenario));
    let (event, tree_1) = setup(&mut scenario, &clock);
    let scenario_buyer = begin(buyer);
    let proof = get_proof(&tree_1, 0);
    increment_for_testing(&mut clock, 10);

    free_sale(
      &mut event,
      0,
      utf8(b"VIP Ticket"),
      0,
      utf8(b"0"),
      proof,
      &clock,
      ctx(&mut scenario_buyer),
    );
    clock::destroy_for_testing(clock);
    next_tx(&mut scenario_buyer, buyer);

    // A shared CNT object is created
    let cnt = take_shared<CNT>(&mut scenario_buyer);

    // The available seats is reduced
    assert!(get_available_seats(&event) == 99, 1);

    return_shared(event);
    return_shared(cnt);
    end(scenario_buyer);
    end(scenario);
  }

  #[test(buyer=@0xf1)]
  fun test_sale_should_mint_cnt(buyer: address) {
    free_purchase(buyer);
  }

  #[test(buyer=@0xf1)]
  #[expected_failure(abort_code = 0x0, location = ticketland::primary_market)]
  fun test_should_fail_if_sale_not_open(buyer: address) {
    let scenario = begin(@admin);
    let clock = clock::create_for_testing(ctx(&mut scenario));
    let (event, tree_1) = setup(&mut scenario, &clock);
    let scenario_buyer = begin(buyer);
    let proof = get_proof(&tree_1, 0);

    free_sale(
      &mut event,
      0,
      utf8(b"VIP Ticket"),
      0,
      utf8(b"0"),
      proof,
      &clock,
      ctx(&mut scenario_buyer),
    );

    return_shared(event);
    clock::destroy_for_testing(clock);
    end(scenario);
    end(scenario_buyer);
  }

  #[test(buyer=@0xf1)]
  #[expected_failure(abort_code = 0x0, location = ticketland::primary_market)]
  fun test_should_fail_if_sale_not_closed(buyer: address) {
    let scenario = begin(@admin);
    let clock = clock::create_for_testing(ctx(&mut scenario));
    let (event, tree_1) = setup(&mut scenario, &clock);
    let scenario_buyer = begin(buyer);
    increment_for_testing(&mut clock, 21);
    let proof = get_proof(&tree_1, 0);

    free_sale(
      &mut event,
      0,
      utf8(b"VIP Ticket"),
      0,
      utf8(b"0"),
      proof,
      &clock,
      ctx(&mut scenario_buyer),
    );

    return_shared(event);
    clock::destroy_for_testing(clock);
    end(scenario);
    end(scenario_buyer);
  }

  #[test(buyer=@0xf1)]
  #[expected_failure(abort_code = 0x0, location = ticketland::merkle_tree)]
  fun test_should_fail_if_wrong_mt_proof(buyer: address) {
    let scenario = begin(@admin);
    let clock = clock::create_for_testing(ctx(&mut scenario));
    let (event, tree_1) = setup(&mut scenario, &clock);
    let scenario_buyer = begin(buyer);
    increment_for_testing(&mut clock, 10);
    let proof = get_proof(&tree_1, 1); // wrong proof

    free_sale(
      &mut event,
      0,
      utf8(b"VIP Ticket"),
      0,
      utf8(b"0"),
      proof,
      &clock,
      ctx(&mut scenario_buyer),
    );

    return_shared(event);
    clock::destroy_for_testing(clock);
    end(scenario);
    end(scenario_buyer);
  }

  #[test(buyer=@0xf1)]
  #[expected_failure(abort_code = 0x1, location = ticketland::primary_market)]
  fun test_should_fail_if_seat_index_does_to_belong_ticket_type(buyer: address) {
    let scenario = begin(@admin);
    let clock = clock::create_for_testing(ctx(&mut scenario));
    let (event, tree_1) = setup(&mut scenario, &clock);
    let scenario_buyer = begin(buyer);
    increment_for_testing(&mut clock, 10);
    let proof = get_proof(&tree_1, 0);

    free_sale(
      &mut event,
      1, // ticket type index
      utf8(b"VIP Ticket"),
      0, // seat index does not belong to ticket type index
      utf8(b"1"),
      proof,
      &clock,
      ctx(&mut scenario_buyer),
    );

    return_shared(event);
    clock::destroy_for_testing(clock);
    end(scenario);
    end(scenario_buyer);
  }

  #[test(buyer=@0xf1)]
  #[expected_failure(abort_code = 0x2, location = ticketland::primary_market)]
  fun test_should_fail_if_seat_not_available(buyer: address) {
    let scenario = begin(@admin);
    let clock = clock::create_for_testing(ctx(&mut scenario));
    let (event, tree_1) = setup(&mut scenario, &clock);
    let scenario_buyer = begin(buyer);
    increment_for_testing(&mut clock, 10);
    let proof = get_proof(&tree_1, 0);

    free_sale(
      &mut event,
      0,
      utf8(b"VIP Ticket"),
      0,
      utf8(b"0"),
      proof,
      &clock,
      ctx(&mut scenario_buyer),
    );
    next_tx(&mut scenario_buyer, buyer);
    // try to get the same ticket again
    free_sale(
      &mut event,
      0,
      utf8(b"VIP Ticket"),
      0,
      utf8(b"0"),
      proof,
      &clock,
      ctx(&mut scenario_buyer),
    );

    return_shared(event);
    clock::destroy_for_testing(clock);
    end(scenario);
    end(scenario_buyer);
  }
}
