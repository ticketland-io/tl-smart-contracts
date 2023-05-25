module ticketland::event {
  use sui::object::{Self, UID};
  use sui::tx_context::{Self, TxContext};
  use std::string::String;
  use sui::transfer::{transfer};
  use std::vector;

  friend ticketland::event_registry;

  const E_START_TIME_BEFORE_END: u64 = 0;
  const E_SEAT_RANGE: u64 = 1;
  const E_MT_ROOT: u64 = 3;

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
    name: String,
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

  fun create_event_capacity(available_tickets: u32): EventCapacity {
    EventCapacity {
      available_tickets,
      seats: vector[],
    }
  }

  public(friend) fun create_event(
    n_tickets: u32,
    start_time: u64,
    end_time: u64,
    ctx: &mut TxContext
  ) {
    let event = Event {
      id: object::new(ctx),
      n_tickets,
      start_time,
      end_time,
      event_capacity: create_event_capacity(n_tickets),
      ticket_types: vector[],
    };

    transfer(event, tx_context::sender(ctx));
  }

  public entry fun add_ticket_type(
    name: String,
    mt_root: vector<u8>,
    n_tickets: u32,
    sale_start_time: u64,
    sale_end_time: u64,
    seat_range: vector<u32>,
    event: &mut Event,
    _ctx: &mut TxContext
  ) {
    assert!(sale_start_time < sale_end_time, E_START_TIME_BEFORE_END);
    assert!(vector::length(&mt_root) == 32, E_MT_ROOT);
    assert!(vector::length(&seat_range) == 2, E_MT_ROOT);

    vector::push_back(&mut event.ticket_types, TicketType {
      name,
      mt_root,
      n_tickets,
      sale_start_time,
      sale_end_time,
      seat_range
    });
  }
}
