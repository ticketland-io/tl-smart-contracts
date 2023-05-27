module ticketland::attendance {
  use sui::tx_context::{TxContext};
  use sui::object::{Self, UID};
  use sui::transfer::{share_object};
  use sui::vec_map::{Self, VecMap};
  use ticketland::ticket::{CNT, get_cnt_id, get_cnt_event_id};

  friend ticketland::event_registry;

  /// Error
  const E_UNAUTHORIZED: u64 = 0;

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

  /// An operator can mark that the owner of a ticket(CNT) has attended an event. We can't directly update the
  /// CNT object since it is owned, we can only get an immutable reference. The owner of a CNT can later call
  /// confirm_attended to update that field
  public fun set_attended(
    cnt: &CNT,
    config: &mut Config,
    cap: &OperatorCap,
  ) {
    assert!(get_cnt_event_id(cnt) == cap.event_id, E_UNAUTHORIZED);
    vec_map::insert(&mut config.attendace, get_cnt_id(cnt), true);
  }
}
