module ticketland::event_registry {
  use sui::tx_context::{Self, TxContext};
  use sui::object::{Self, UID};
  use sui::event;
  use sui::transfer::{transfer, share_object};
  use ticketland::event as tl_event;

  /// Capability allowing the bearer to execute admin related tasks
  struct AdminCap has key {id: UID}

  struct Config has key {
    id: UID,
    /// The list of supported coins that can be used in purchases. These are the addresses (taken from UID::ID::address)
    /// of th CoinMetadata objects related with each currency. CoinMetadata is unique for each Coin
    supported_coins: vector<address>,
    /// The fees collected by the protocol during various interaction i.e. primary sale, secondary etc.
    protocol_fee: u64,
    /// The address that will be receiving those fees
    protocol_fee_address: address,
  }

  // Events
  struct ConfigUpdated has copy, drop {}

  /// Module initializer to be executed when this module is published by the the Sui runtime
  fun init (ctx: &mut TxContext) {
    let admin_cap = AdminCap {
      id: object::new(ctx),
    };

    let config = Config {
      id: object::new(ctx), 
      supported_coins: vector[],
      protocol_fee: 0,
      protocol_fee_address: tx_context::sender(ctx),
    };

    transfer(admin_cap, tx_context::sender(ctx));
    share_object(config);
  }

  /// Allows admin to update the configs
  public entry fun update_config(
    _cap: &AdminCap,
    config: &mut Config,
    supported_coins: vector<address>,
    protocol_fee: u64,
    protocol_fee_address: address,
    _ctx: &mut TxContext
  ) {
    config.supported_coins = supported_coins;
    config.protocol_fee = protocol_fee;
    config.protocol_fee_address = protocol_fee_address;

    event::emit(ConfigUpdated {});
  }

  /// Allows anyone to create a new event
  public(friend) entry fun create_event(
    n_tickets: u32,
    start_time: u64,
    end_time: u64,
    available_tickets: u32,
    ctx: &mut TxContext
  ) {
    tl_event::create_event(n_tickets, start_time, end_time, available_tickets, ctx);
  }

  #[test_only]
  /// Wrapper of module initializer for testing. Test modules cannot directly call init() so we have to go though this
  /// public function instead
  public fun test_init(ctx: &mut TxContext) {
    init(ctx)
  }
}
