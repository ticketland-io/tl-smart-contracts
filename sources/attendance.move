module ticketland::attendance {
  use sui::tx_context::{TxContext};
  use sui::object::{Self, UID};
  use sui::transfer::{share_object};
  use sui::event::{emit};
  use sui::table::{Self, Table};
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
    attendance: Table<address, bool>,
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
      attendance: table::new(ctx),
    };

    share_object(attendance);
  }

  public fun has_attended(cnt_id: address, config: &Config): bool {
    if(!table::contains(&config.attendance, cnt_id)) {
      return false
    };

    *table::borrow(&config.attendance, cnt_id)
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
    table::add(&mut config.attendance, cnt_id, true);

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

  #[test_only]
  public fun create_config(ctx: &mut TxContext): Config {
    Config {
      id: object::new(ctx),
      attendance: table::new(ctx),
    }
  }

  #[test_only]
  public fun set_attended_for_testing(cnt: &CNT, config: &mut Config) {
    let cnt_id = get_cnt_id(cnt);
    table::add(&mut config.attendance, cnt_id, true);
  }

  #[test_only]
  public fun drop_config(config: Config) {
    let Config {id, attendance} = config;

    object::delete(id);
    table::drop(attendance);
  }
}
