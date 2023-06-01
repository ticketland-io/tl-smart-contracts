#[test_only]
module ticketland::event_registry_test {
  use std::type_name;
  use std::string::{utf8};
  use std::ascii;
  use std::hash::sha3_256;
  use sui::sui::SUI;
  use sui::test_scenario::{
    Scenario, begin, ctx, next_tx, end, take_from_sender, return_to_sender, 
    take_shared, return_shared,
  };
  use ticketland::usdc::{USDC, Self};
  use ticketland::event::{Event, NftEvent, EventOrganizerCap};
  use ticketland::event_registry::{
    Self, Config, AdminCap, update_config, get_protocol_info, is_coin_supported,
    create_event,
  };

  fun init_currencies(scenario: &mut Scenario) {
    usdc::test_init(ctx(scenario));
  }

  fun setup(scenario: &mut Scenario) {
    init_currencies(scenario);
    event_registry::test_init(ctx(scenario));
    next_tx(scenario, @admin);
  }

  fun setup_config(scenario: &mut Scenario) {
    let admin_cap = take_from_sender<AdminCap>(scenario);
    let config = take_shared<Config>(scenario);

    update_config(
      &admin_cap,
      &mut config,
      vector[
        type_name::into_string(type_name::get<USDC>()),
        type_name::into_string(type_name::get<SUI>()),
      ],
      1000,
      @protocol_fee_address,
      vector[@operator_1, @operator_2],
    );

    return_to_sender(scenario, admin_cap);
    return_shared(config);
    next_tx(scenario, @admin);
  }

  #[test]
  fun test_update_config() {
    let scenario = begin(@admin);
    setup(&mut scenario);
    setup_config(&mut scenario);

    let config = take_shared<Config>(&mut scenario);
    let (fee, protocol_addr) = get_protocol_info(&config);
    
    assert!(fee == 1000, 1);
    assert!(protocol_addr == @protocol_fee_address, 1);
    assert!(is_coin_supported(&config, &sha3_256(ascii::into_bytes(type_name::into_string(type_name::get<USDC>())))), 1);
    assert!(is_coin_supported(&config, &sha3_256(ascii::into_bytes(type_name::into_string(type_name::get<SUI>())))), 1);

    return_shared(config);
    end(scenario);
  }

  #[test]
  fun test_create_event() {
    let scenario = begin(@admin);
    setup(&mut scenario);
    setup_config(&mut scenario);
    let config = take_shared<Config>(&mut scenario);

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
      &config,
      ctx(&mut scenario),
    );
    next_tx(&mut scenario, @admin);

    // A new shared Event is created
    let event = take_shared<Event>(&mut scenario);
    return_shared(event);

    // A new owned NftEvent is created
    let nft_event = take_from_sender<NftEvent>(&mut scenario);
    return_to_sender(&mut scenario, nft_event);

    // A new owned EventOrganizer is  create
    let cap = take_from_sender<EventOrganizerCap>(&mut scenario);
    return_to_sender(&mut scenario, cap);

    return_shared(config);
    end(scenario);
  }
}
