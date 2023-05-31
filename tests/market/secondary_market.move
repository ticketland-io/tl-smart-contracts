#[test_only]
module ticketland::secondary_market_test {
    use sui::test_scenario::{
    Self, ctx, next_tx, end, take_from_sender, return_to_sender, 
    take_shared, return_shared,
  };
  // use sui::coin::{Coin};
  use std::type_name;
  use sui::sui::SUI;
  use sui::coin::{Coin};
  use ticketland::usdc::{USDC};
  use ticketland::fixed_price_sale_test::{fixed_price_purchase};
  use ticketland::price_oracle::{ExchangeRate, create_exchange_rate};
  use ticketland::secondary_market::{list};
  use ticketland::ticket::{CNT};
  use ticketland::event::{Event};
  use ticketland::common_test::{to_base};

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
    let exchange_rate = setup();
    fixed_price_purchase(buyer);

    let scenario_buyer = test_scenario::begin(buyer);
    let cnt = take_from_sender<CNT>(&mut scenario_buyer);
    let event = take_shared<Event>(&mut scenario_buyer);

    list<Coin<USDC>>(&event, cnt, to_base(110), &exchange_rate, ctx(&mut scenario_buyer));

    return_to_sender(&mut scenario_buyer, exchange_rate);
    return_shared(event);
    end(scenario_buyer);
  }
}
