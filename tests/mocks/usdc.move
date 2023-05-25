// A mock USDC coin
#[test_only]
module ticketland::usdc {
  use sui::object::{Self, UID};
  use std::option;
  use sui::coin;
  use sui::transfer;
  use sui::tx_context::{Self, TxContext};

  // transferable witness pattern https://examples.sui.io/patterns/transferable-witness.html
  struct USDC has drop {}
  struct WitnessCarrier has key {id: UID, witness: USDC}

  fun init(ctx: &mut TxContext) {
    transfer::transfer(
      WitnessCarrier {id: object::new(ctx), witness: USDC {}},
      tx_context::sender(ctx)
    )
  }

  #[test_only]
  /// Wrapper of module initializer for testing
  public fun test_init(ctx: &mut TxContext) {
    init(ctx)
  }

  public fun create(otw: USDC, ctx: &mut TxContext) {
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

  /// Unwrap a carrier and get the inner WITNESS type.
  public fun get_witness(carrier: WitnessCarrier): USDC {
    let WitnessCarrier {id, witness} = carrier;
    object::delete(id);
    
    witness
  }
}
