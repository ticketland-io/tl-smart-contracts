module ticketland::market_utils {
  use sui::coin::{Coin, value};
  use ticketland::event_registry::{Config, get_protocol_info};

  /// Constants
  const BASIS_POINTS: u64 = 10_000;

  /// Errors
  const E_INSUFFICIENT_BALANCE: u64 = 0;

  public fun has_enough_balance<T>(coins: &Coin<T>, price: u64) {
    assert!(value(coins) >= price, E_INSUFFICIENT_BALANCE);
  } 

  public fun split_payable_amount<T>(
    coins: &Coin<T>,
    price: u64,
    config: &Config,
  ): (u64, u64, address) {
    has_enough_balance(coins, price);

    let (protocol_fee, protocol_fee_address) = get_protocol_info(config);
    let fees = (price * protocol_fee) / BASIS_POINTS;
    let payable_amount = price - fees;

    (fees, payable_amount, protocol_fee_address)
  }
}
