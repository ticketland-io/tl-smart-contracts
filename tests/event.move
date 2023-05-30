#[test_only]
module ticketland::event_test {
  use std::string::{utf8};
  use ticketland::merkle_tree_test::{create_tree, root};
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
  use ticketland::event_registry::{create_config, drop_config};
  use ticketland::common_test::to_base;
  use ticketland::sale_type::{
    Free, FixedPrice, add_free_sale_type, add_fixed_price_sale_type,
  };

  fun create_new_event(scenario: &mut Scenario, admin: address) {
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
    next_tx(scenario, admin);
  }

  fun setup_ticket_types(
    scenario: &mut Scenario,
    clock: &Clock,
    event: &mut Event,
    admin: address,
    protocol_fee_address: address,
    operator1: address,
    operator2: address,
  ) {
    let organizer_cap = take_from_sender<EventOrganizerCap>(scenario);
    let tree = create_tree(100, 0, 59);
    let root_1 = *root(&tree);
    let root_2 = *root(&create_tree(100, 60, 99));

    add_ticket_types(
      vector[utf8(b"type1"), utf8(b"type2")],
      vector[root_1, root_2],
      vector[60, 40],
      vector[10, 10],
      vector[20, 20],
      vector[vector[0, 59], vector[60, 99]],
      event,
      &organizer_cap,
      ctx(scenario),
    );

    // create a dummy config
    let config = create_config(
      vector[
        type_name::into_string(type_name::get<USDC>()),
        type_name::into_string(type_name::get<SUI>()),
      ],
      1000,
      protocol_fee_address,
      vector[operator1, operator2],
      ctx(scenario),
    );
    
    // add free sale type to the first ticket type
    add_free_sale_type(
      event,
      0,
      clock,
      &organizer_cap,
    );

    // add fixed price sale type to the first ticket type
    add_fixed_price_sale_type<USDC>(
      event,
      1,
      to_base(100),
      &config,
      clock,
      &organizer_cap,
    );
    
    next_tx(scenario, admin);
    drop_config(config);
    return_to_sender(scenario, organizer_cap);
  }

  fun setup(scenario: &mut Scenario, admin: address) {
    test_init(ctx(scenario));
    create_new_event(scenario, admin);
    next_tx(scenario, admin);
  }

  #[test(admin=@0xab)]
  fun test_create_event(admin: address) {
    let scenario = test_scenario::begin(admin);
    setup(&mut scenario, admin);
  
    // A new shared Event is created
    let event = take_shared<Event>(&mut scenario);
    assert!(get_event_creator(&event) == admin, 1);
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

  #[test(admin=@0xab)]
  fun test_add_ticket_types(admin: address) {
    let scenario = test_scenario::begin(admin);
    setup(&mut scenario, admin);

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

  #[test(admin=@0xab, protocol_fee_address=@0xbc, operator1=@0xcd, operator2=@0xde)]
  fun test_add_sale_type(
    admin: address,
    protocol_fee_address: address,
    operator1: address,
    operator2: address,
  ) {
    let scenario = test_scenario::begin(admin);
    setup(&mut scenario, admin);

    
    let event = take_shared<Event>(&mut scenario);
    let clock = clock::create_for_testing(ctx(&mut scenario));

    setup_ticket_types(
      &mut scenario,
      &mut clock,
      &mut event,
      admin,
      protocol_fee_address,
      operator1,
      operator2,
    );

    // check that sale types were added. It will abort if sale types cannot be found
    get_sale_type<Free>(&event, 0);
    get_sale_type<FixedPrice<USDC>>(&event, 1);

    return_shared(event);
    clock::destroy_for_testing(clock);
    end(scenario);
  }

  #[test(admin=@0xab, protocol_fee_address=@0xbc, operator1=@0xcd, operator2=@0xde)]
  #[expected_failure(abort_code = 0x4, location = ticketland::event)]
  fun test_add_sale_type_fails_when_wrong_time(
    admin: address,
    protocol_fee_address: address,
    operator1: address,
    operator2: address,
  ) {
    let scenario = test_scenario::begin(admin);
    setup(&mut scenario, admin);

    let event = take_shared<Event>(&mut scenario);
    let clock = clock::create_for_testing(ctx(&mut scenario));
    clock::set_for_testing(&mut clock, 101);

    setup_ticket_types(
      &mut scenario,
      &mut clock,
      &mut event,
      admin,
      protocol_fee_address,
      operator1,
      operator2,
    );

    return_shared(event);
    clock::destroy_for_testing(clock);
    end(scenario);
  }
}
