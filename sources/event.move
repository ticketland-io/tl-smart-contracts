module ticketland::event {
  use sui::package;
  use sui::display;
  use sui::object::{Self, UID, ID, uid_to_inner, uid_to_address};
  use sui::tx_context::{TxContext, sender};
  use std::string::{utf8, String};
  use sui::clock::{Self, Clock};
  use sui::event::{emit};
  use sui::address;
  use sui::transfer::{transfer, public_transfer, share_object};
  use sui::dynamic_field as dfield;
  use std::vector;
  use sui::vec_map::{Self, VecMap};
  use ticketland::bitmap::{Self, Bitmap};

  friend ticketland::event_registry;
  friend ticketland::sale_type;
  friend ticketland::primary_market;
  friend ticketland::nft_ticket;

  /// constants
  const SALE_TYPE_KEY: vector<u8> = b"sale_type";

  /// Errors
  const E_START_TIME_BEFORE_END: u64 = 0;
  const E_MT_ROOT: u64 = 1;
  const E_TICKET_TYPE_SET: u64 = 2;
  const E_SALE_TYPE_SET: u64 = 3;

  /// One-Time-Witness for the module.
  struct EVENT has drop {}

  struct NftEvent has key {
    id: UID,
    /// Internal off-chain event id
    event_id: String,
    /// The name of the NFT
    name: String,
    /// The description
    description: String,
    /// The image uri
    image_uri: String,
    /// Custom metadata attributes
    properties: VecMap<String, String>
  }

  // Cap that allow the bearer to manage events. It has store ability because we want free native transfers on this object
  struct EventOrganizerCap has key, store {
    id: UID,
    event_id: address,
  }

  struct Event has key {
    id: UID,
    /// Internal off-chain event id
    event_id: String, 
    /// The id of the NftEvent associated with this event
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
    tickets_sold: u32,

    /// A bitmap which has n_tickets bits that represent each seat
    /// By default all bits are 0. When a ticket at ticket index N (Nth bit) is purchased
    /// then the bit is flipped to 1 indicating that the seat is not available
    /// Bitmap allows us to store compact data e.g With 12500 bytes we can represent up to 12500 * 8 = 100_000 seats
    seats: Bitmap,
  }

  struct SeatRange has store {
    // from inclusive
    from: u64,
    // to exclusive
    to: u64
  }

  /// Thhe ticket type. Note this struct will have SaleType attached as a dynamic field. This is so we can support
  /// hetergenous sale type values. We could also use Bag (which uses dynamic fields under the hood as well)
  struct TicketType has store {
    id: UID,
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
    seat_range: SeatRange,
  }

  // Events
  struct EventCreated has copy, drop {
    id: ID,
    creator: address,
  }

  struct EventNftCreated has copy, drop {
    id: ID,
    creator: address,
  }

  /// Use one-time-witness and publisher patterns to create a new Display Object for the Event and Event NFTs objects
  /// more details https://examples.sui.io/basics/display.html and https://docs.sui.io/build/sui-object-display
  fun init(otw: EVENT, ctx: &mut TxContext) {
    let creator = sender(ctx);

    let event_nft_keys = vector[
      utf8(b"Event id"),
      utf8(b"Name"),
      utf8(b"Description"),
      utf8(b"Image Uri"),
      utf8(b"Link"),
      utf8(b"Creator"),
    ];

    let event_nft_values = vector[
      utf8(b"{event_id}"),
      utf8(b"{name}"),
      utf8(b"{description}"),
      utf8(b"{image_uri}"),
      utf8(b"https://app.ticketland/events/{event_id}"),
      address::to_string(creator),
    ];

    let publisher = package::claim(otw, ctx);
    let display = display::new_with_fields<NftEvent>(&publisher, event_nft_keys, event_nft_values, ctx);
    // Commit first version of `Display` to apply changes.
    display::update_version(&mut display);

    public_transfer(publisher, creator);
    public_transfer(display, creator);
  }

  fun create_event_capacity(): EventCapacity {
    EventCapacity {
      tickets_sold: 0,
      seats: bitmap::empty(),
    }
  }

  /// Create a new shared Event object and the onwed by the event creator NftEvent object
  public(friend) fun create_event(
    event_id: String,
    name: String,
    description: String,
    image_uri: String,
    n_tickets: u32,
    start_time: u64,
    end_time: u64,
    ctx: &mut TxContext
  ) {
    // the event id
    let id = object::new(ctx);
    let nft_event_id = object::new(ctx);

    let nft_event = NftEvent {
      id: nft_event_id,
      event_id,
      name,
      description,
      image_uri,
      // We add this to make it future proof. We might want to add additional custom metadata
      // attributes to each event NFT in the future. So to make module upgrades compatible, we
      // want to have this field in the struct
      properties: vec_map::empty(),
    };

    let creator = sender(ctx);
    let event = Event {
      id,
      event_id,
      event_nft_id: uid_to_inner(&nft_event.id),
      creator, 
      n_tickets,
      start_time,
      end_time,
      event_capacity: create_event_capacity(),
      ticket_types: vector[],
    };

    let organizer_cap = EventOrganizerCap {
      id: object::new(ctx),
      event_id: uid_to_address(&event.id),
    };

    emit(EventCreated {
      id: uid_to_inner(&event.id),
      creator,
    });

    emit(EventNftCreated {
      id: uid_to_inner(&nft_event.id),
      creator,
    });

    // Event is shared as it will be immutably used in other function call by other users
    share_object(event);
    // However, the Event NFT itself is owned by the creator
    transfer(nft_event, creator);
    // Create and transfer the organizer cap as well so the event creator can manage events
    transfer(organizer_cap, creator);
  }

  /// Allows the bearer of the organizer cap to add the given ticket types to the event. It can only be called once per event
  public entry fun add_ticket_types(
    names: vector<String>,
    mt_roots: vector<vector<u8>>,
    n_tickets_list: vector<u32>,
    sale_start_times: vector<u64>,
    sale_end_times: vector<u64>,
    seat_ranges: vector<vector<u64>>,
    event: &mut Event,
    _cap: &EventOrganizerCap,
    ctx: &mut TxContext
  ) {
    assert!(vector::length(&event.ticket_types) == 0, E_TICKET_TYPE_SET);

    let i = 0;
    let len = vector::length(&names);

    while(i < len) {
      let sale_start_time = *vector::borrow(&sale_start_times, i);
      let sale_end_time = *vector::borrow(&sale_end_times, i);
      let mt_root = *vector::borrow(&mt_roots, i);
      let seat_range = *vector::borrow(&seat_ranges, i);
      let seat_range = SeatRange {
        from: *vector::borrow(&seat_range, 0),
        to: *vector::borrow(&seat_range, 1),
      };

      assert!(sale_start_time < sale_end_time, E_START_TIME_BEFORE_END);
      assert!(vector::length(&mt_root) == 32, E_MT_ROOT);

      let name = *vector::borrow(&names, i);
      let n_tickets = *vector::borrow(&n_tickets_list, i);

      vector::push_back(&mut event.ticket_types, TicketType {
        id: object::new(ctx),
        name,
        mt_root,
        n_tickets,
        sale_start_time,
        sale_end_time,
        seat_range,
      });

      i = i + 1;
    };
  }

  // We're not allowed to change the ticket type once it's set
  fun assert_add_sale_type(start_time: u64, ticket_type: &TicketType, clock: &Clock) {
    assert!(clock::timestamp_ms(clock) < start_time, E_SALE_TYPE_SET);
    assert!(!dfield::exists_(&ticket_type.id, SALE_TYPE_KEY), E_SALE_TYPE_SET);
  }

  /// Called by the sale type module to add the given generic sale type as a dynamic field of TicketType
  /// object. We use dynamic fields to support heterogeneous struct type which is not possible with a VecMap.
  /// Note we could also use Bag which uses dynamic fields under the hood anyways.
  public(friend) fun add_sale_type<ST: store>(
    sale_type: ST,
    event: &mut Event,
    ticket_type_index: u64,
    clock: &Clock
  ) {
    let ticket_type = vector::borrow_mut(&mut event.ticket_types, ticket_type_index);
    assert_add_sale_type(event.start_time, ticket_type, clock);
    dfield::add<vector<u8>, ST>(&mut ticket_type.id, SALE_TYPE_KEY, sale_type);
  }

  public(friend) fun event_organizer_cap_into_event_id(cap: &EventOrganizerCap): address {
    cap.event_id
  }

  // Will chekc if the given ticket type if past of the event
  public fun is_event_ticket_type(event: &Event, ticket_type_id: address): bool {
    let len = vector::length(&event.ticket_types);
    let i = 0;

    while (i < len) {
      let ticket_type = vector::borrow(&event.ticket_types, i);
      
      if(uid_to_address(&ticket_type.id) == ticket_type_id) {
        return true;
      };
      
      i = i + 1;
    };

    false
  }

  public fun get_event_id(event: &Event): String {
    event.event_id
  }

  public fun get_available_seats(event: &Event): u32 {
    event.n_tickets - event.event_capacity.tickets_sold
  }

  public fun get_ticket_type(event: &Event, index: u64): &TicketType {
    vector::borrow(&event.ticket_types, index)
  }
  
  public fun get_ticket_type_sale_time(ticket_type: &TicketType): (u64, u64) {
    (ticket_type.sale_start_time, ticket_type.sale_end_time)
  }

  /// Checks if the given seat index belongs to the seats assigned for the given ticket type
  public fun get_seat_range(ticket_type: &TicketType): (u64, u64) {
    (ticket_type.seat_range.from, ticket_type.seat_range.to)
  }
  
  public fun get_seats(event: &Event): &Bitmap {
    &event.event_capacity.seats
  }

  public fun get_ticket_type_mt_root(ticket_type: &TicketType): &vector<u8> {
    &ticket_type.mt_root
  }

  public(friend) fun increment_tickets_sold(event: &mut Event) {
    event.event_capacity.tickets_sold = event.event_capacity.tickets_sold + 1;
  }

  public(friend) fun update_seats(event: &mut Event, seat_index: u64) {
    bitmap::flip_bit(&mut event.event_capacity.seats, seat_index);
  }
}
