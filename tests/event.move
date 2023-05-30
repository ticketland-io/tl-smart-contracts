#[test_only]
module ticketland::event_test {
  use std::string::{utf8};
  use ticketland::merkle_tree_test::{create_tree, root};
  use sui::test_scenario::{
    Self, Scenario, ctx, next_tx, end, take_from_sender, return_to_sender, 
    take_shared, return_shared,
  };
  use ticketland::event::{
    EventOrganizerCap, Event, NftEvent, create_event, test_init, add_ticket_types,
    get_ticket_type, get_event_creator, get_available_seats,get_resale_cap_bps, get_royalty_bps,
    get_ticket_type_mt_root, has_ticket_type, get_ticket_type_id, get_seat_range,
  };

  fun create_new_event(scenario: &mut Scenario, admin: address) {
    create_event(
      utf8(b"Event 1"),
      utf8(b"Description 1"),
      utf8(b"https://app.ticketland.io/1"),
      vector[utf8(b"key1"), utf8(b"key2")],
      vector[utf8(b"value1"), utf8(b"value1")],
      1000,
      1685441840,
      1685442840,
      1000,
      100,
      ctx(scenario),
    );
    next_tx(scenario, admin);
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
    let root_1 = *root(&create_tree(100, 0, 59));
    std::debug::print(&root_1);
    let root_2 = *root(&create_tree(100, 60, 99));
    std::debug::print(&root_2);

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

    let ticket_type = get_ticket_type(&event, 0);
    let (l, r) = get_seat_range(ticket_type);
    assert!(l == 0 && r == 59, 1);
    assert!(*get_ticket_type_mt_root(ticket_type) == root_1, 1);
    assert!(has_ticket_type(&event, &get_ticket_type_id(ticket_type)), 1);
    

    return_to_sender(&mut scenario, organizer_cap);
    return_shared(event);
    end(scenario);
  }
}
