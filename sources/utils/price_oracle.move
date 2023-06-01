module ticketland::price_oracle {
  use sui::tx_context::{TxContext, sender};
  use sui::transfer::{transfer, share_object};
  use sui::object::{Self, UID};
  use sui::vec_map::{Self, VecMap};
  use ticketland::collection_utils::{
    compare_ascii_strings,
    get_composite_key,
  };
  use std::vector;
  use std::ascii;

  // Constants
  const SMALLER: u8 = 1;
  const BASIS_POINTS: u64 = 10_000;

  /// Errors
  const E_LEN_MISMATCH: u64 = 0;

  /// Capability allowing the bearer to execute admin related tasks
  struct AdminCap has key {id: UID}

  struct ExchangeRate has key {
    id: UID,
    // The exhange rate from token0 to token1. Note token0 and token1 are sorted so it's
    // token0:token1 => exchange_rate
    inner: VecMap<vector<u8>, u64>,
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

  /// Updates the given list of coins. The 
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
      let rate = vector::borrow_mut(&mut rates, i);

      let (coin0, coin1) = if (compare_ascii_strings(from, to) == SMALLER) {
        (from, to)
      } else {
        *rate = get_reverse_rate(*rate);
        (to, from)
      };

      // check if key exists otherwise insert new
      let pair = get_composite_key(*coin0, *coin1);
  
      if(vec_map::contains(&exhange_rate.inner, &pair)) {
        let value = vec_map::get_mut(&mut exhange_rate.inner, &pair);
        *value = *rate;
      } else {
        vec_map::insert(&mut exhange_rate.inner, pair, *rate);
      };

      i = i + 1;
    };
  }

  /// if from is smaller then we just return the rate because that's how it's stored.
  /// else we need to convert the rate into the symetrical value. For example is 1 SUI => 0.5 USDC then
  /// if from is SUI we just return 0.5 else we return 1/0.5 = 2. Note we use 10,000 BASIS points for all
  /// calculations and to store rates
  fun get_reverse_rate(rate: u64): u64 {
    (BASIS_POINTS / rate) * BASIS_POINTS
  }

  public fun get_exchange_rate(
    from: ascii::String,
    to: ascii::String,
    exhange_rate: &ExchangeRate,
  ): u64 {
    if(from == to) {
      return BASIS_POINTS
    };
    
    *vec_map::get(&exhange_rate.inner, &get_composite_key(from, to))
  }

  public fun exchange_value(
    from: ascii::String,
    to: ascii::String,
    value: u64,
    exhange_rate: &ExchangeRate,
  ): u64 {
    (value * get_exchange_rate(from, to, exhange_rate)) / BASIS_POINTS
  }

  #[test_only]
  public fun create_exchange_rate(
    coins: vector<vector<ascii::String>>,
    rates: vector<u64>,
    ctx: &mut TxContext,
  ): ExchangeRate {
    let exchnage_rate = ExchangeRate {
      id: object::new(ctx),
      inner: vec_map::empty(),
    };

    let admin_cap = AdminCap {id: object::new(ctx)};
    update_exchange_rates(
      coins,
      rates,
      &admin_cap,
      &mut exchnage_rate
    );

    let AdminCap {id} = admin_cap;
    object::delete(id);

    exchnage_rate
  }

  #[test_only]
  public fun drop_exchange_rate(exhange_rate: ExchangeRate) {
    let ExchangeRate {id, inner: _} = exhange_rate;
    object::delete(id);
  }
}
