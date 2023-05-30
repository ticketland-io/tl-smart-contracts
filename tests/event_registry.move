#[test_only]
module ticketland::event_registry_test {
  use std::type_name;
  use sui::sui::SUI;
  use sui::test_scenario::{
    Self, Scenario, ctx, next_tx, end, take_from_sender, return_to_sender, 
    take_shared, return_shared,
  };
  use ticketland::usdc::{USDC, Self};
  use ticketland::event_registry::{
    Self, Config, AdminCap, update_config, get_protocol_info, is_coin_supported,
  };

  fun init_currencies(scenario: &mut Scenario) {
    usdc::test_init(ctx(scenario));
  }

  fun setup(scenario: &mut Scenario, admin: address) {
    event_registry::test_init(ctx(scenario));
    next_tx(scenario, admin);
  }

  fun setup_config(
    scenario: &mut Scenario,
    admin: address,
    protocol_fee_address: address,
    operator1: address,
    operator2: address,
  ) {
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
      protocol_fee_address,
      vector[operator1, operator2],
    );

    return_to_sender(scenario, admin_cap);
    return_shared(config);
    next_tx(scenario, admin);
  }


  #[test(admin=@0xab, protocol_fee_address=@0xbc, operator1=@0xcd, operator2=@0xde)]
  fun test_update_config(
    admin: address,
    protocol_fee_address: address,
    operator1: address,
    operator2: address,
  ) {
    let scenario = test_scenario::begin(admin);
    init_currencies(&mut scenario);
    setup(&mut scenario, admin);
    setup_config(&mut scenario, admin, protocol_fee_address, operator1, operator2);

    let config = take_shared<Config>(&mut scenario);
    let (fee, protocol_addr) = get_protocol_info(&config);
    
    assert!(fee == 1000, 1);
    assert!(protocol_addr == protocol_fee_address, 1);
    assert!(is_coin_supported(&config, &type_name::into_string(type_name::get<USDC>())), 1);
    assert!(is_coin_supported(&config, &type_name::into_string(type_name::get<SUI>())), 1);

    return_shared(config);
    end(scenario);
  }
}
