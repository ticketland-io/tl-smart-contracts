#[test_only]
module ticketland::event_registry_test {
  use sui::test_scenario::{Self, Scenario, ctx, end};
  use ticketland::event_registry;
  use ticketland::usdc::{Self};

  fun init_currencies(scenario: &mut Scenario) {
    usdc::test_init(ctx(scenario));
  }

  fun setup(scenario: &mut Scenario) {
    event_registry::test_init(ctx(scenario));
  }

  #[test(admin=@0xad)]
  fun test_update_config(admin: address) {
    let scenario = test_scenario::begin(admin);
    init_currencies(&mut scenario);
    setup(&mut scenario);
    // event_registry_test::update_config(ctx(&mut scenario));

    end(scenario);
  }
}
