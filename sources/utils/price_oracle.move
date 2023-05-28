module ticketland::price_oracle {
  use sui::tx_context::{TxContext, sender};
  use sui::transfer::{transfer, share_object};
  use sui::object::{Self, UID};
  use sui::vec_map::{Self, VecMap};
  use ticketland::collection_utils::{compare_ascii_strings, concat_ascii_strings};
  use std::vector;
  use std::ascii;

  // Constants
  const SMALLER: u8 = 2;

  /// Errors
  const E_LEN_MISMATCH: u64 = 0;

  /// Capability allowing the bearer to execute admin related tasks
  struct AdminCap has key {id: UID}

  struct ExchangeRate has key {
    id: UID,
    // The exhange rate from token0 to token1. Note token0 and token1 are sorted so it's
    // token0:token1 => exchange_rate
    inner: VecMap<ascii::String, u64>,
  }

  /// Module initializer to be executed when this module is published by the the Sui runtime
  fun init (ctx: &mut TxContext) {
    let admin_cap = AdminCap {
      id: object::new(ctx),
    };

    let exchnage_rate = ExchangeRate {
      id: object::new(ctx), 
      inner: vec_map::empty(),
    };

    transfer(admin_cap, sender(ctx));
    share_object(exchnage_rate);
  }

  public fun update_exchange_rates(
    coins: vector<vector<ascii::String>>,
    rates: vector<u64>,
    _cap: &AdminCap,
    exhange_rate: &mut ExchangeRate,
  ) {
    let len = vector::length(&coins);
    assert!(len == vector::length(&rates), E_LEN_MISMATCH);

    let i = 0;
    while (i < len) {
      let pair = vector::borrow(&coins, i);
      let from = vector::borrow(pair, 0);
      let to = vector::borrow(pair, 1);

      let (coin0, coin1) = if (compare_ascii_strings(from, to) == SMALLER) {
        (from, to)
      } else {
        (to, from)
      };

      let rate = *vector::borrow(&rates, i);
      vec_map::insert(&mut exhange_rate.inner, concat_ascii_strings(*coin0, *coin1), rate);

      i = i + 1;
    };
  }

  public fun get_exchange_rate(
    from: ascii::String,
    to: ascii::String,
    exhange_rate: &mut ExchangeRate,
  ): u64 {
    let rate = *vec_map::get(&exhange_rate.inner, &concat_ascii_strings(from, to));

    // if from is smallet then we just return the rate because that's how it's stored.
    // else we need to convert the rate into the symetrical value. For example is 1 SUI => 0.5 USDC then
    // if from is SUI we just return 0.5 else we return 1/0.5 = 2
    if(compare_ascii_strings(&from, &to) == SMALLER) {
      rate
    } else {
      1 / rate
    }
  }

  public fun exchange_value(
    from: ascii::String,
    to: ascii::String,
    value: u64,
    exhange_rate: &mut ExchangeRate,
  ): u64 {
    value * get_exchange_rate(from, to, exhange_rate)
  }
}
