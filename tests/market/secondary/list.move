#[test_only]
module ticketland::secondary_market_list_test {
    use sui::test_scenario::{
    Self, ctx, next_tx, end, take_shared, return_shared,
  };
  // use sui::coin::{Coin};
  use std::type_name;
  use sui::sui::SUI;
  use ticketland::usdc::{USDC};
  use ticketland::fixed_price_sale_test::{fixed_price_purchase};
  use ticketland::free_sale_test::{free_purchase};
  use ticketland::price_oracle::{ExchangeRate, create_exchange_rate, drop_exchange_rate};
  use ticketland::secondary_market::{list};
  use ticketland::ticket::{CNT};
  use ticketland::event::{Event};
  use ticketland::common_test::{to_base};
  use ticketland::event_test::{create_new_event};

  fun setup(): ExchangeRate {
    let scenario = test_scenario::begin(@admin);
    let coins = vector[
      vector[
        type_name::into_string(type_name::get<USDC>()),
        type_name::into_string(type_name::get<SUI>()),
      ],
    ];
    // 1 USDC = 0.5 SUI in 10,000 BPS. Note this will be store as SUI => USDC => 20,000 i.e 1 SUI = 2 USDC
    let rates = vector[5000];
    let exchange_rate = create_exchange_rate(coins, rates, ctx(&mut scenario));

    next_tx(&mut scenario, @admin);
    end(scenario);

    exchange_rate
  }

  #[test(buyer=@0xf1)]
  fun test_list_cnt(buyer: address) {
    let scenario_buyer = test_scenario::begin(buyer);
    fixed_price_purchase(buyer);
    let exchange_rate = setup();
    let cnt = take_shared<CNT>(&mut scenario_buyer);
    let event = take_shared<Event>(&mut scenario_buyer);

    list<USDC>(&event, &cnt, to_base(110), &exchange_rate, ctx(&mut scenario_buyer));

    drop_exchange_rate(exchange_rate);
    return_shared(cnt);
    return_shared(event);
    end(scenario_buyer);
  }

  #[test(buyer=@0xf1, chunk=@0xd0d)]
  #[expected_failure(abort_code = 0x7, location = ticketland::secondary_market)]
  fun test_list_should_fail_if_not_owner(buyer: address, chunk: address) {
    let scenario_buyer = test_scenario::begin(buyer);
    fixed_price_purchase(buyer);
    let exchange_rate = setup();
    let cnt = take_shared<CNT>(&mut scenario_buyer);
    let event = take_shared<Event>(&mut scenario_buyer);
    let scenario_chunk= test_scenario::begin(chunk);

    list<USDC>(&event, &cnt, to_base(110), &exchange_rate, ctx(&mut scenario_chunk));

    drop_exchange_rate(exchange_rate);
    return_shared(cnt);
    return_shared(event);
    end(scenario_buyer);
    end(scenario_chunk);
  }

  #[test(buyer=@0xf1, chunk=@0xd0d)]
  #[expected_failure(abort_code = 0x0, location = ticketland::secondary_market)]
  fun test_list_should_fail_if_wrong_event(buyer: address) {
    let scenario_buyer = test_scenario::begin(buyer);
    fixed_price_purchase(buyer);
    let exchange_rate = setup();
    let cnt = take_shared<CNT>(&mut scenario_buyer);
    create_new_event(&mut scenario_buyer);
    next_tx(&mut scenario_buyer, buyer);
    let wrong_event = take_shared<Event>(&mut scenario_buyer);

    list<USDC>(&wrong_event, &cnt, to_base(110), &exchange_rate, ctx(&mut scenario_buyer));

    drop_exchange_rate(exchange_rate);
    return_shared(cnt);
    return_shared(wrong_event);
    end(scenario_buyer);
  }

  #[test(buyer=@0xf1, chunk=@0xd0d)]
  #[expected_failure(abort_code = 0x4, location = ticketland::secondary_market)]
  fun test_list_should_fail_if_free_cnt(buyer: address) {
    let scenario_buyer = test_scenario::begin(buyer);
    free_purchase(buyer);
    let exchange_rate = setup();
    next_tx(&mut scenario_buyer, buyer);
    let cnt = take_shared<CNT>(&mut scenario_buyer);
    let event = take_shared<Event>(&mut scenario_buyer);

    list<USDC>(&event, &cnt, to_base(110), &exchange_rate, ctx(&mut scenario_buyer));

    drop_exchange_rate(exchange_rate);
    return_shared(cnt);
    return_shared(event);
    end(scenario_buyer);
  }

  #[test(buyer=@0xf1, chunk=@0xd0d)]
  #[expected_failure(abort_code = 0x1, location = ticketland::secondary_market)]
  fun test_list_should_fail_if_max_sale_violated(buyer: address) {
    let scenario_buyer = test_scenario::begin(buyer);
    fixed_price_purchase(buyer);
    let exchange_rate = setup();
    let cnt = take_shared<CNT>(&mut scenario_buyer);
    let event = take_shared<Event>(&mut scenario_buyer);

    // Purchased for 100, max_resale cap 10% thus max resale price is 110
    list<USDC>(&event, &cnt, to_base(111), &exchange_rate, ctx(&mut scenario_buyer));

    drop_exchange_rate(exchange_rate);
    return_shared(cnt);
    return_shared(event);
    end(scenario_buyer);
  }
}
