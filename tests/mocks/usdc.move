// A mock USDC coin
#[test_only]
module ticketland::usdc {
  use std::option;
  use sui::coin;
  use sui::transfer;
  use sui::tx_context::{Self, TxContext};

  struct USDC has drop {}

  fun init(otw: USDC, ctx: &mut TxContext) {
    let (treasury, metadata) = coin::create_currency(
      otw,
      6,
      b"USDC",
      b"USDC",
      b"USDC Stablecoin",
      option::none(),
      ctx,
    );

    transfer::public_freeze_object(metadata);
    transfer::public_transfer(treasury, tx_context::sender(ctx));
  }

  #[test_only]
  /// Wrapper of module initializer for testing
  public fun test_init(ctx: &mut TxContext) {
    init(USDC {}, ctx)
  }
}
