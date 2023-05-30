#[test_only]
module ticketland::event_test {
  use std::string::{utf8};
  use sui::test_scenario::{
    Self, Scenario, ctx, next_tx, end, take_from_sender, return_to_sender, 
    take_shared, return_shared,
  };
  use ticketland::event::{
    EventOrganizerCap, Event, NftEvent, create_event, test_init, add_ticket_types
  };

  fun create_new_event(scenario: &mut Scenario, admin: address) {
    create_event(
      utf8(b"Event 1"),
      utf8(b"Description 1"),
      utf8(b"https://app.ticketland.io/1"),
      vector[utf8(b"key1"), utf8(b"key2")],
      vector[utf8(b"value1"), utf8(b"value1")],
      100_000,
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

    // add_ticket_types(
    //   vector[utf8(b"type1"), utf8(b"type2")],
    //   mt_roots: vector<vector<u8>>,
    //   n_tickets_list: vector<u32>,
    //   sale_start_times: vector<u64>,
    //   sale_end_times: vector<u64>,
    //   seat_ranges: vector<vector<u64>>,

    //   &mut event,
    //   &organizer_cap,
    //   ctx(&mut scenario),
    // );

    return_to_sender(&mut scenario, organizer_cap);
    return_shared(event);
    end(scenario);
  }
}
