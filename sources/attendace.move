module ticketland::attendance {
  use sui::tx_context::{TxContext};
  use sui::object::{Self, UID};
  use sui::transfer::{share_object};
  use sui::vec_map::{Self, VecMap};
  use sui::event::{emit};
  use ticketland::ticket::{Self, CNT, get_cnt_id, get_cnt_event_id};

  friend ticketland::event_registry;

  /// Error
  const E_UNAUTHORIZED: u64 = 0;
  const E_DID_NOT_ATTEND: u64 = 1;

  struct OperatorCap has key, store {
    id: UID,
    event_id: address,
  }

  struct Config has key {
    id: UID,
    /// cnt id (as address) => attended the event?
    attendace: VecMap<address, bool>,
  }

  // Events
  struct SetAttended has copy, drop {
    cnt_id: address,
  }

  struct ConfirmAttended has copy, drop {
    cnt_id: address,
  }

  fun init(ctx: &mut TxContext) {
    let attendance = Config {
      id: object::new(ctx),
      attendace: vec_map::empty(),
    };

    share_object(attendance);
  }

  public fun has_attended(cnt_id: address, config: &Config): bool {
    *vec_map::get(&config.attendace, &cnt_id)
  }

  /// A function that is called by the event organizer and transfers a new operator cap to the given address
  /// This must be called right after an event is created.
  public(friend) fun create_op_cap(event_id: address, ctx: &mut TxContext): OperatorCap {
    OperatorCap {
      id: object::new(ctx),
      event_id,
    }
  }

  /// An operator can mark that the owner of a ticket(CNT) has attended an event. We can't directly update the
  /// CNT object since it is owned, we can only get an immutable reference. The owner of a CNT can later call
  /// confirm_attended to update that field
  public entry fun set_attended(
    cnt: &CNT,
    config: &mut Config,
    cap: &OperatorCap,
  ) {
    assert!(get_cnt_event_id(cnt) == cap.event_id, E_UNAUTHORIZED);
    
    let cnt_id = get_cnt_id(cnt);
    vec_map::insert(&mut config.attendace, cnt_id, true);

    emit(SetAttended {cnt_id});
  }

  /// Called by the onwer of CNT to update the `attended` field of the CNT object.
  /// One of the operators must have called `set_attended` before for this function to succeed.
  public entry fun confirm_attended(cnt: &mut CNT, config: &mut Config) {
    let cnt_id = get_cnt_id(cnt);
    assert!(has_attended(cnt_id, config), E_DID_NOT_ATTEND);

    ticket::set_attended(cnt);
    emit(ConfirmAttended {cnt_id})
  }
}
