module ticketland::attendance {
  use sui::tx_context::{TxContext};
  use sui::object::{Self, UID};
  use sui::transfer::{share_object};
  use sui::vec_map::{Self, VecMap};

  struct Config has key {
    id: UID,
    /// cnt id (as address) => attended the event?
    cnts: VecMap<address, bool>,
  }

  fun init(ctx: &mut TxContext) {
    let attendance = Config {
      id: object::new(ctx),
      cnts: vec_map::empty(),
    };

    share_object(attendance);
  }
}
