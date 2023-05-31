#[test_only]
module ticketland::event_test {
  use std::string::{utf8};
  use ticketland::merkle_tree_test::{Tree, create_tree, root};
  use sui::clock::{Self, Clock};
  use std::type_name;
  use sui::sui::SUI;
  use sui::test_scenario::{
    Self, Scenario, ctx, next_tx, end, take_from_sender, return_to_sender, 
    take_shared, return_shared,
  };
  use ticketland::event::{
    EventOrganizerCap, Event, NftEvent, create_event, test_init, add_ticket_types,
    get_ticket_type, get_event_creator, get_available_seats,get_resale_cap_bps, get_royalty_bps,
    get_ticket_type_mt_root, has_ticket_type, get_ticket_type_id, get_seat_range, get_ticket_type_sale_time,
    get_sale_type,
  };
  use ticketland::usdc::{USDC};
  use ticketland::event_registry::{Config, create_config, drop_config};
  use ticketland::common_test::to_base;
  use ticketland::sale_type::{
    Free, FixedPrice, add_free_sale_type, add_fixed_price_sale_type, add_refundable_sale_type,
  };

  public fun create_new_event(scenario: &mut Scenario) {
    create_event(
      utf8(b"Event 1"),
      utf8(b"Description 1"),
      utf8(b"https://app.ticketland.io/1"),
      vector[utf8(b"key1"), utf8(b"key2")],
      vector[utf8(b"value1"), utf8(b"value1")],
      1000,
      100, // start ts
      200, // end ts
      1000,
      100,
      ctx(scenario),
    );
    next_tx(scenario, @admin);
  }

  public fun create_new_config(scenario: &mut Scenario): Config {
    create_config(
      vector[
        type_name::into_string(type_name::get<USDC>()),
        type_name::into_string(type_name::get<SUI>()),
      ],
      1000,
      @protocol_fee_address,
      vector[@operator_1, @operator_2],
      ctx(scenario),
    )
  }

  public fun setup_ticket_types(
    scenario: &mut Scenario,
    organizer_cap: &EventOrganizerCap,
    clock: &Clock,
    event: &mut Event,
  ): (Tree, Tree, Tree) {
    let tree_1 = create_tree(100, 0, 0);
    let root_1 = *root(&tree_1);
    let tree_2 = create_tree(100, 1, 59);
    let root_2 = *root(&tree_2);
    let tree_3 = create_tree(100, 60, 99);
    let root_3 = *root(&tree_3);

    add_ticket_types(
      vector[utf8(b"type1"), utf8(b"type2"), utf8(b"type3")],
      vector[root_1, root_2, root_3],
      vector[1, 59, 40],
      vector[10, 10, 10],
      vector[20, 20, 20],
      vector[vector[0, 0], vector[1, 59], vector[60, 99]],
      event,
      organizer_cap,
      ctx(scenario),
    );

    // create a dummy config
    let config = create_new_config(scenario);

    // add free sale type to the first ticket type
    add_free_sale_type(
      event,
      0,
      clock,
      organizer_cap,
    );

    // add fixed price sale type to the first ticket type
    add_fixed_price_sale_type<USDC>(
      event,
      1,
      to_base(100),
      &config,
      clock,
      organizer_cap,
    );

    add_refundable_sale_type<SUI>(
      event,
      2,
      to_base(50),
      &config,
      clock,
      organizer_cap,
    );
    
    next_tx(scenario, @admin);
    drop_config(config);

    (tree_1, tree_2, tree_3)
  }

  fun setup(scenario: &mut Scenario) {
    test_init(ctx(scenario));
    create_new_event(scenario);
    next_tx(scenario, @admin);
  }

  #[test]
  fun test_create_event() {
    let scenario = test_scenario::begin(@admin);
    setup(&mut scenario);
  
    // A new shared Event is created
    let event = take_shared<Event>(&mut scenario);
    assert!(get_event_creator(&event) == @admin, 1);
    assert!(get_available_seats(&event) == 1000, 1);
    assert!(get_resale_cap_bps(&event) == 1000, 1);
    assert!(get_royalty_bps(&event) == 100, 1);
    return_shared(event);


    // A new owned NftEvent is 
    let nft_event = take_from_sender<NftEvent>(&mut scenario);
    return_to_sender(&mut scenario, nft_event);

    // A new owned EventOrganizer is  create
    let cap = take_from_sender<EventOrganizerCap>(&mut scenario);
    return_to_sender(&mut scenario, cap);

    end(scenario);
  }

  #[test]
  fun test_add_ticket_types() {
    let scenario = test_scenario::begin(@admin);
    setup(&mut scenario);

    let organizer_cap = take_from_sender<EventOrganizerCap>(&mut scenario);
    let event = take_shared<Event>(&mut scenario);
    let tree = create_tree(100, 0, 59);
    let root_1 = *root(&tree);
    let root_2 = *root(&create_tree(100, 60, 99));

    add_ticket_types(
      vector[utf8(b"type1"), utf8(b"type2")],
      vector[root_1, root_2],
      vector[60, 40],
      vector[0, 0],
      vector[10, 10],
      vector[vector[0, 59], vector[60, 99]],
      &mut event,
      &organizer_cap,
      ctx(&mut scenario),
    );

    // ticket type 1
    let ticket_type = get_ticket_type(&event, 0);
    let (l, r) = get_seat_range(ticket_type);
    let (start, end) = get_ticket_type_sale_time(ticket_type);
    assert!(l == 0 && r == 59, 1);
    assert!(*get_ticket_type_mt_root(ticket_type) == root_1, 1);
    assert!(has_ticket_type(&event, &get_ticket_type_id(ticket_type)), 1);
    assert!(start == 0 && end == 10, 1);

    // ticket type 2
    let ticket_type = get_ticket_type(&event, 1);
    let (l, r) = get_seat_range(ticket_type);
    let (start, end) = get_ticket_type_sale_time(ticket_type);
    assert!(l == 60 && r == 99, 1);
    assert!(*get_ticket_type_mt_root(ticket_type) == root_2, 1);
    assert!(has_ticket_type(&event, &get_ticket_type_id(ticket_type)), 1);
    assert!(start == 0 && end == 10, 1);

    return_to_sender(&mut scenario, organizer_cap);
    return_shared(event);
    end(scenario);
  }

  #[test]
  fun test_add_sale_type() {
    let scenario = test_scenario::begin(@admin);
    setup(&mut scenario);
    let organizer_cap = take_from_sender<EventOrganizerCap>(&mut scenario);
    let event = take_shared<Event>(&mut scenario);
    let clock = clock::create_for_testing(ctx(&mut scenario));

    setup_ticket_types(
      &mut scenario,
      &organizer_cap,
      &mut clock,
      &mut event,
    );

    // check that sale types were added. It will abort if sale types cannot be found
    get_sale_type<Free>(&event, 0);
    get_sale_type<FixedPrice<USDC>>(&event, 1);

    return_to_sender(&mut scenario, organizer_cap);
    return_shared(event);
    clock::destroy_for_testing(clock);
    end(scenario);
  }

  #[test]
  #[expected_failure(abort_code = 0x4, location = ticketland::event)]
  fun test_add_sale_type_fails_when_wrong_time() {
    let scenario = test_scenario::begin(@admin);
    setup(&mut scenario);
    let organizer_cap = take_from_sender<EventOrganizerCap>(&mut scenario);
    let event = take_shared<Event>(&mut scenario);
    let clock = clock::create_for_testing(ctx(&mut scenario));
    clock::set_for_testing(&mut clock, 101);

    setup_ticket_types(
      &mut scenario,
      &organizer_cap,
      &mut clock,
      &mut event,
    );

    return_to_sender(&mut scenario, organizer_cap);
    return_shared(event);
    clock::destroy_for_testing(clock);
    end(scenario);
  }

  #[test]
  #[expected_failure(abort_code = 0x3, location = ticketland::event)]
  fun test_cannot_reset_sale_type() {
    let scenario = test_scenario::begin(@admin);
    setup(&mut scenario);
    let organizer_cap = take_from_sender<EventOrganizerCap>(&mut scenario);
    let event = take_shared<Event>(&mut scenario);
    let clock = clock::create_for_testing(ctx(&mut scenario));

    setup_ticket_types(
      &mut scenario,
      &organizer_cap,
      &mut clock,
      &mut event,
    );
    
    // add free sale type to the first ticket type
    add_free_sale_type(
      &mut event,
      0,
      &clock,
      &organizer_cap,
    );

    return_shared(event);
    return_to_sender(&mut scenario, organizer_cap);
    clock::destroy_for_testing(clock);
    end(scenario);
  }
}
