module ticketland::event_registry {
  use sui::tx_context::{TxContext, sender};
  use std::string::{String};
  use sui::vec_map::{Self, VecMap};
  use std::vector;
  use sui::object::{Self, UID};
  use std::ascii;
  use sui::event;
  use sui::transfer::{transfer, share_object};
  use ticketland::event as tl_event;

  /// Capability allowing the bearer to execute admin related tasks
  struct AdminCap has key {id: UID}

  struct Config has key {
    id: UID,
    /// The list of supported coins that can be used in purchases. The string value is a sui::type_name::TypeName
    supported_coins: VecMap<ascii::String, bool>,
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
      supported_coins: vec_map::empty(),
      protocol_fee: 0,
      protocol_fee_address: sender(ctx),
    };

    transfer(admin_cap, sender(ctx));
    share_object(config);
  }

  /// Allows admin to update the configs
  public entry fun update_config(
    _cap: &AdminCap,
    config: &mut Config,
    supported_coins: vector<ascii::String>,
    protocol_fee: u64,
    protocol_fee_address: address,
    _ctx: &mut TxContext,
  ) {
    // reset old vec_map
    config.supported_coins = vec_map::empty();
    config.protocol_fee = protocol_fee;
    config.protocol_fee_address = protocol_fee_address;

    let len = vector::length(&supported_coins);
    let i = 0;

    while (i < len) {
      let coin_type = *vector::borrow(&supported_coins, i);
      vec_map::insert(&mut config.supported_coins, coin_type, true);

      i = i + 1;
    };

    event::emit(ConfigUpdated {});
  }

  /// Allows anyone to create a new event
  /// 
  /// # Arguments
  /// 
  /// * `n_tickets` - Total number of tickets
  /// * `start_time` - Start of the event
  /// * `end_time` - End time of the event
  public(friend) entry fun create_event(
    event_id: String,
    name: String,
    description: String,
    image_uri: String,
    n_tickets: u32,
    start_time: u64,
    end_time: u64,
    ctx: &mut TxContext
  ) {
    tl_event::create_event(
      event_id,
      name,
      description,
      image_uri,
      n_tickets,
      start_time,
      end_time,
      ctx,
    );
  }

  public fun is_coin_supported(config: &Config, coin_type: &ascii::String): bool {
    vec_map::contains(&config.supported_coins, coin_type)
  }

  #[test_only]
  /// Wrapper of module initializer for testing. Test modules cannot directly call init() so we have to go though this
  /// public function instead
  public fun test_init(ctx: &mut TxContext) {
    init(ctx)
  }
}
