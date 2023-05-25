module ticketland::event {
  use sui::object::{Self, UID, ID};
  use sui::tx_context::{Self, TxContext};
  use std::string::String;
  use sui::transfer::{transfer, share_object};
  use std::vector;

  friend ticketland::event_registry;

  const E_START_TIME_BEFORE_END: u64 = 0;
  const E_SEAT_RANGE: u64 = 1;
  const E_MT_ROOT: u64 = 3;
  const E_TICKET_TYPE_SET: u64 = 3;

  struct EventNFT has key {
    id: UID,
    /// The name of the NFT
    name: String,
    /// The image uri
    image_uri: String,
  }

  // Cap that allow the bearer to manage events. It has store ability because we want free native transfers on this object
  struct OrganizerCap has key, store { id: UID }

  struct Event has key {
    id: UID,
    /// The id of the EventNFT associated with this event
    event_nft_id: ID,
    /// The event creator
    creator: address,
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
  struct TicketType has store, copy, drop {
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

  /// Create a new shared Event object and the onwed by the event creator EventNFT object
  public(friend) fun create_event(
    name: String,
    image_uri: String,
    n_tickets: u32,
    start_time: u64,
    end_time: u64,
    ctx: &mut TxContext
  ) {
    let event_nft = EventNFT {
      id: object::new(ctx),
      name,
      image_uri,
    };

    let creator = tx_context::sender(ctx);
    let event = Event {
      id: object::new(ctx),
      event_nft_id: object::uid_to_inner(&event_nft.id),
      creator, 
      n_tickets,
      start_time,
      end_time,
      event_capacity: create_event_capacity(n_tickets),
      ticket_types: vector[],
    };

    let organizer_cap = OrganizerCap {id: object::new(ctx)};

    // Event is shared as it will be immutably used in other function call by other users
    share_object(event);
    // However, the Event NFT itself is owned by the creator
    transfer(event_nft, creator);
    // Create and transfer the organizer cap as well so the event creator can manage events
    transfer(organizer_cap, creator)
  }

  /// Allows the bearer of the organizer cap to add the given ticket types to the event. It can only be called once per event
  public entry fun add_ticket_types(
    names: vector<String>,
    mt_roots: vector<vector<u8>>,
    n_tickets_list: vector<u32>,
    sale_start_times: vector<u64>,
    sale_end_times: vector<u64>,
    seat_ranges: vector<vector<u32>>,
    event: &mut Event,
    _cap: &OrganizerCap,
    _ctx: &mut TxContext
  ) {
    assert!(vector::length(&event.ticket_types) == 0, E_TICKET_TYPE_SET);

    let i = 0;
    let len = vector::length(&names);

    while(i < len) {
      let sale_start_time = *vector::borrow(&sale_start_times, i);
      let sale_end_time = *vector::borrow(&sale_end_times, i);
      let mt_root = *vector::borrow(&mt_roots, i);
      let seat_range = *vector::borrow(&seat_ranges, i);

      assert!(sale_start_time < sale_end_time, E_START_TIME_BEFORE_END);
      assert!(vector::length(&mt_root) == 32, E_MT_ROOT);
      assert!(vector::length(&seat_range) == 2, E_MT_ROOT);

      let name = *vector::borrow(&names, i);
      let n_tickets = *vector::borrow(&n_tickets_list, i);

      vector::push_back(&mut event.ticket_types, TicketType {
        name,
        mt_root,
        n_tickets,
        sale_start_time,
        sale_end_time,
        seat_range
      });

      i = i + 1;
    };
  }
}
