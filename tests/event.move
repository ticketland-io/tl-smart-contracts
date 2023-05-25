#[test_only]
module ticketland::event_test {
  use sui::tx_context::{last_created_object_id};
  use sui::test_scenario::{Self, Scenario, ctx, end, next_tx};
  use sui::object::{id_from_address};
  use ticketland::event;
  use ticketland::usdc::{Self, USDC, WitnessCarrier};
  use sui::coin::{Self};

  fun init_currency(scenario: &mut Scenario) {
    usdc::test_init(ctx(scenario));
    let id1 = id_from_address(last_created_object_id(ctx(scenario)));
    let witness_carier = test_scenario::take_from_sender_by_id<WitnessCarrier>(scenario, id1);
    usdc::create(usdc::get_witness(witness_carier), ctx(scenario))
  }

  #[test(admin=@0xad)]
  fun test_update_config(admin: address) {
    let scenario = test_scenario::begin(admin);
    init_currency(&mut scenario);

    next_tx(&mut scenario, admin);

    next_tx(&mut scenario, admin);
    let coins = coin::mint_for_testing(100, ctx(&mut scenario));

    next_tx(&mut scenario, admin);
    event::update_config<USDC>(coins, ctx(&mut scenario));

    end(scenario);
  }
}
