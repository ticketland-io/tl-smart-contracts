#[test_only]
module ticketland::secondary_market_list_test {
  use sui::test_scenario::{
    TransactionEffects, begin, ctx, next_tx, end, take_shared, return_shared,
  };
  use std::type_name;
  use sui::sui::SUI;
  use ticketland::usdc::{USDC};
  use ticketland::fixed_price_sale_test::{fixed_price_purchase};
  use ticketland::free_sale_test::{free_purchase};
  use ticketland::price_oracle::{ExchangeRate, create_exchange_rate, drop_exchange_rate};
  use ticketland::secondary_market::{Listing, list};
  use ticketland::ticket::{CNT};
  use ticketland::event::{Event};
  use ticketland::common_test::{to_base};
  use ticketland::event_test::{create_new_event};

  fun setup(): ExchangeRate {
    let scenario = begin(@admin);
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

  public fun list_cnt(seller: address): TransactionEffects {
    let scenario_seller = begin(seller);
    fixed_price_purchase(seller);
    let exchange_rate = setup();
    let cnt = take_shared<CNT>(&mut scenario_seller);
    let event = take_shared<Event>(&mut scenario_seller);

    list<USDC>(&event, &cnt, to_base(110), &exchange_rate, ctx(&mut scenario_seller));

    drop_exchange_rate(exchange_rate);
    return_shared(cnt);
    return_shared(event);
    end(scenario_seller)
  }

  #[test(seller=@0xf1)]
  fun test_list_cnt(seller: address) {
    list_cnt(seller);
    
    let scenario_seller = begin(seller);
    let listing = take_shared<Listing<USDC>>(&mut scenario_seller);

    return_shared(listing);
    end(scenario_seller);
  }

  #[test(seller=@0xf1, chunk=@0xd0d)]
  #[expected_failure(abort_code = 0x7, location = ticketland::secondary_market)]
  fun test_list_should_fail_if_not_owner(seller: address, chunk: address) {
    let scenario_seller = begin(seller);
    fixed_price_purchase(seller);
    let exchange_rate = setup();
    let cnt = take_shared<CNT>(&mut scenario_seller);
    let event = take_shared<Event>(&mut scenario_seller);
    let scenario_chunk= begin(chunk);

    list<USDC>(&event, &cnt, to_base(110), &exchange_rate, ctx(&mut scenario_chunk));

    drop_exchange_rate(exchange_rate);
    return_shared(cnt);
    return_shared(event);
    end(scenario_seller);
    end(scenario_chunk);
  }

  #[test(seller=@0xf1, chunk=@0xd0d)]
  #[expected_failure(abort_code = 0x0, location = ticketland::secondary_market)]
  fun test_list_should_fail_if_wrong_event(seller: address) {
    let scenario_seller = begin(seller);
    fixed_price_purchase(seller);
    let exchange_rate = setup();
    let cnt = take_shared<CNT>(&mut scenario_seller);
    create_new_event(&mut scenario_seller);
    next_tx(&mut scenario_seller, seller);
    let wrong_event = take_shared<Event>(&mut scenario_seller);

    list<USDC>(&wrong_event, &cnt, to_base(110), &exchange_rate, ctx(&mut scenario_seller));

    drop_exchange_rate(exchange_rate);
    return_shared(cnt);
    return_shared(wrong_event);
    end(scenario_seller);
  }

  #[test(seller=@0xf1, chunk=@0xd0d)]
  #[expected_failure(abort_code = 0x4, location = ticketland::secondary_market)]
  fun test_list_should_fail_if_free_cnt(seller: address) {
    let scenario_seller = begin(seller);
    free_purchase(seller);
    let exchange_rate = setup();
    next_tx(&mut scenario_seller, seller);
    let cnt = take_shared<CNT>(&mut scenario_seller);
    let event = take_shared<Event>(&mut scenario_seller);

    list<USDC>(&event, &cnt, to_base(110), &exchange_rate, ctx(&mut scenario_seller));

    drop_exchange_rate(exchange_rate);
    return_shared(cnt);
    return_shared(event);
    end(scenario_seller);
  }

  #[test(seller=@0xf1, chunk=@0xd0d)]
  #[expected_failure(abort_code = 0x1, location = ticketland::secondary_market)]
  fun test_list_should_fail_if_max_sale_violated(seller: address) {
    let scenario_seller = begin(seller);
    fixed_price_purchase(seller);
    let exchange_rate = setup();
    let cnt = take_shared<CNT>(&mut scenario_seller);
    let event = take_shared<Event>(&mut scenario_seller);

    // Purchased for 100, max_resale cap 10% thus max resale price is 110
    list<USDC>(&event, &cnt, to_base(111), &exchange_rate, ctx(&mut scenario_seller));

    drop_exchange_rate(exchange_rate);
    return_shared(cnt);
    return_shared(event);
    end(scenario_seller);
  }
}
