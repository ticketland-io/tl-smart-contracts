module ticketland::event {
  use sui::tx_context::{Self, TxContext};
  use sui::object::{Self, UID};
  use sui::transfer::{transfer, public_transfer};
  use std::type_name::TypeName;
  
  use std::debug;
  use sui::coin::{Coin};

  // use ticketland::constants::{MAX_PROTOCOL_FEE};

  /// Capability allowing the bearer to execute admin related tasks
  struct AdminCap has key {id: UID}

  struct Config has key {
    id: UID,
    /// The list of supported coins that can be used in purchases
    supported_coins: vector<TypeName>,
    /// The fees collected by the protocol during various interaction i.e. primary sale, secondary etc.
    protocol_fee: u64,
    /// The address that will be receiving those fees
    protocol_fee_address: address,
  }

  struct Event has key {
    id: UID,
    /// Total number of issued tickets
    n_tickets: u32,
    /// Start of the event
    start_time: u64,
    /// The end time of the event
    end_time: u64,
    /// The event capacity data
    event_capacity: EventCapacity,
    /// The different ticket type variants
    ticket_types: vector<TicketType>,
  }

  struct EventCapacity has store {
    /// Number of tickets still available for sale
    available_tickets: u32,

    /// A bitmap which has n_tickets bits that represent each seat
    /// By default all bits are 0. When a ticket at ticket index N (Nth bit) is purchased
    /// then the bit is flipped to 1 indicating that the seat is not available
    /// Bitmap allows us to store compact data e.g With 12500 bytes we can represent up to 12500 * 8 = 100_000 seats
    seats: vector<u8>
  }

  /// Thhe ticket type. Note this struct will have SaleType attached as a dynamic field. This is so we can support
  /// hetergenous sale type values. We could also use Bag (which uses dynamic fields under the hood as well)
  struct TicketType has store, drop {
    /// The name of the ticket type
    name: vector<u8>,
    /// The merkle tree root of the seats list
    mt_root: vector<u8>,
    /// Total number of issued tickets
    n_tickets: u32,
    /// The start time of the sale of this ticket type
    sale_start_time: u64,
    /// The end time of the sale of this ticket type
    sale_end_time: u64,
    /// The range of the seats in the venue this ticket type is for
    /// This vector inludes two items
    seat_range: vector<u32>,
  }

  /// Module initializer to be executed when this module is published by the the Sui runtime
  fun init (ctx: &mut TxContext) {
    let admin_cap = AdminCap {
      id: object::new(ctx),
    };

    transfer(admin_cap, tx_context::sender(ctx));
  }

  /// Allows admin to update the configs
  public entry fun update_config<T>(coins: Coin<T>, ctx: &mut TxContext) {
    debug::print<Coin<T>>(&coins);
    public_transfer(coins, tx_context::sender(ctx));
  }
  // public entry fun update_config(
  //   _cap: AdminCap,

  //   ctx: &mut TxContext
  // ) {

  // }
}
