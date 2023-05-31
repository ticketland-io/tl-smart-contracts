module ticketland::event_registry {
  use sui::tx_context::{TxContext, sender};
  use std::string::{String};
  use sui::vec_map::{Self, VecMap};
  use std::vector;
  use std::hash::sha3_256;
  use sui::object::{Self, UID};
  use std::ascii;
  use sui::event::{emit};
  use sui::transfer::{transfer, public_transfer, share_object};
  use ticketland::attendance::{create_op_cap};
  use ticketland::event as tl_event;

  /// Errors
  const E_PROPERTY_VEC_MISMATCH: u64 = 0;

  /// Capability allowing the bearer to execute admin related tasks
  struct AdminCap has key {id: UID}

  struct Config has key {
    id: UID,
    /// The list of supported coins that can be used in purchases. The string value is a sui::type_name::TypeName
    /// Note it's the sha3 hash of TypeName of Coin<T>
    supported_coins: VecMap<vector<u8>, bool>,
    /// The fees collected by the protocol during various interaction i.e. primary sale, secondary etc.
    protocol_fee: u64,
    /// The address that will be receiving those fees
    protocol_fee_address: address,
    /// A list of operators that can get access to various functions like setting attendance for CNTs
    operators: vector<address>,
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
      operators: vector[],
    };

    transfer(admin_cap, sender(ctx));
    share_object(config);
  }

  public fun get_protocol_info(config: &Config): (u64, address) {
    (config.protocol_fee, config.protocol_fee_address)
  }

  /// Allows admin to update the configs
  public entry fun update_config(
    _cap: &AdminCap,
    config: &mut Config,
    supported_coins: vector<ascii::String>,
    protocol_fee: u64,
    protocol_fee_address: address,
    operators: vector<address>,
  ) {
    // reset old vec_map
    config.supported_coins = vec_map::empty();
    config.protocol_fee = protocol_fee;
    config.protocol_fee_address = protocol_fee_address;
    config.operators = operators;

    let len = vector::length(&supported_coins);
    let i = 0;

    while (i < len) {
      let coin_type = *vector::borrow(&supported_coins, i);
      let key = sha3_256(ascii::into_bytes(coin_type));
      vec_map::insert(&mut config.supported_coins, key, true);

      i = i + 1;
    };

    emit(ConfigUpdated {});
  }

  /// Allows anyone to create a new event
  /// 
  /// # Arguments
  /// 
  /// * `name` - The event name
  /// * `description` - The event description
  /// * `image_uri` - The event image uri
  /// * `n_tickets` - The number of ticket available for this event
  /// * `start_time` - The event start time
  /// * `end_time` - The event end time
  /// * `resale_cap_bps` - The max increase from previous price a ticket can be sold for. This is 10_000 basis point
  /// * `royalty_bps` - The resale fee basis points i.e. royalty fees
  public entry fun create_event(
    name: String,
    description: String,
    image_uri: String,
    property_keys: vector<String>,
    property_values: vector<String>,
    n_tickets: u32,
    start_time: u64,
    end_time: u64,
    resale_cap_bps: u16,
    royalty_bps: u16,
    config: &Config,
    ctx: &mut TxContext
  ) {
    assert!(vector::length(&property_keys) == vector::length(&property_values), E_PROPERTY_VEC_MISMATCH);

    let event_id = tl_event::create_event(
      name,
      description,
      image_uri,
      property_keys,
      property_values,
      n_tickets,
      start_time,
      end_time,
      resale_cap_bps,
      royalty_bps,
      ctx,
    );

    // create an attendance operator_cap. Ticketland is the default operator
    let len = vector::length(&config.operators);
    let i = 0;

    while (i < len) {
      let operator = *vector::borrow(&config.operators, i);  
      let operator_cap = create_op_cap(event_id, ctx);

      public_transfer(operator_cap, operator);
      i = i + 1;
    }
  }

  public fun is_coin_supported(config: &Config, coin_type: &vector<u8>): bool {
    vec_map::contains(&config.supported_coins, coin_type)
  }

  #[test_only]
  /// Wrapper of module initializer for testing. Test modules cannot directly call init() so we have to go though this
  /// public function instead
  public fun test_init(ctx: &mut TxContext) {
    init(ctx)
  }

  #[test_only]
  public fun create_config(
    supported_coins: vector<ascii::String>,
    protocol_fee: u64,
    protocol_fee_address: address,
    operators: vector<address>,
    ctx: &mut TxContext
  ): Config {
    let config = Config {
      id: object::new(ctx), 
      supported_coins: vec_map::empty(),
      protocol_fee: 0,
      protocol_fee_address: sender(ctx),
      operators: vector[],
    };

    let admin_cap = AdminCap {id: object::new(ctx)};

    update_config(
      &admin_cap,
      &mut config,
      supported_coins,
      protocol_fee,
      protocol_fee_address,
      operators,
    );

    let AdminCap {id} = admin_cap;
    object::delete(id);

    config
  }

  #[test_only]
  public fun drop_config(config: Config) {
    let Config {id, supported_coins: _, protocol_fee: _, protocol_fee_address: _, operators: _} = config;
    object::delete(id);
  }
}
