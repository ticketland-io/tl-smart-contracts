module ticketland::attendance {
  use sui::tx_context::{TxContext};
  use sui::object::{Self, UID};
  use sui::transfer::{share_object};
  use sui::vec_map::{Self, VecMap};

  friend ticketland::event_registry;

  struct OperatorCap has key, store {
    id: UID,
    event_id: address,
  }

  struct Config has key {
    id: UID,
    /// cnt id (as address) => attended the event?
    attendace: VecMap<address, bool>,
  }

  fun init(ctx: &mut TxContext) {
    let attendance = Config {
      id: object::new(ctx),
      attendace: vec_map::empty(),
    };

    share_object(attendance);
  }

  /// A function that is called by the event organizer and transfers a new operator cap to the given address
  /// This must be called right after an event is created.
  public(friend) fun create_op_cap(
    event_id: address,
    ctx: &mut TxContext
  ): OperatorCap {
    OperatorCap {
      id: object::new(ctx),
      event_id,
    }
  }

  public fun set_attended(config: &mut Config, cap: &OperatorCap) {
    let event_id = cap.event_id;
    vec_map::insert(&mut config.attendace, event_id, true);
  }
}
