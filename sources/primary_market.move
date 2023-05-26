module ticketland::primary_market {
  use sui::object::{Self, UID, ID};
  use std::vector;
  use sui::clock::{Self, Clock};
  use sui::tx_context::{TxContext};
  use std::string::{Self, String};
  use ticketland::bitmap;
  use ticketland::merkle_tree;
  use ticketland::event::{
    Event, get_ticket_type, get_ticket_type_sale_time, get_available_seats, get_seat_range, get_seats,
    get_ticket_type_mt_root,
  };
  use ticketland::num_utils::{u64_to_str};

  /// Erros
  const E_SALE_CLOSED: u64 = 0;
  const E_INVALID_SEAT_INDEX: u64 = 1;
  const E_NO_AVAILABLE_SEATS: u64 = 2;
  const E_SEAT_NOT_AVAILABLE: u64 = 3;

  fun create_seat_leaf(seat_index: u64, seat_name: String): vector<u8> {
    let p1 = *string::bytes(&u64_to_str(seat_index));
    let p2 = b".";
    let p3 = string::bytes(&seat_name);
    
    vector::append(&mut p1, p2);
    vector::append(&mut p1, *p3);

    p1
  }

  fun pre_purchase(
    event: &Event,
    ticket_type_index: u64,
    seat_index: u64,
    seat_name: String,
    proof: vector<vector<u8>>,
    clock: &Clock,
  ) {
    let now = clock::timestamp_ms(clock);
    let ticket_type = get_ticket_type(event, ticket_type_index);

    // 1. Check sale time
    let (start_time, end_time) = get_ticket_type_sale_time(ticket_type);
    assert!(now >= start_time && now < end_time, E_SALE_CLOSED);

    // 2. Are there any available seats for this type of ticket
    assert!(get_available_seats(event) > 0, E_NO_AVAILABLE_SEATS);

    // 3. Is seat_index within the seat range of the given ticket type
    let (from, to) = get_seat_range(ticket_type);
    assert!(seat_index >= from && seat_index < to, E_INVALID_SEAT_INDEX);

    // 4. Check that the seat_index is available
    assert!(bitmap::is_set(get_seats(event), seat_index), E_SEAT_NOT_AVAILABLE);

    // 5. Verify the merkle path
    let mt_root = get_ticket_type_mt_root(ticket_type);
    merkle_tree::verify(mt_root, proof, create_seat_leaf(seat_index, seat_name));
  }

  fun post_purchase() {

  }

  public entry fun free_sale(
    event: &Event,
    ticket_type_index: u64,
    seat_index: u64,
    seat_name: String,
    proof: vector<vector<u8>>,
    clock: &Clock,
    ctx: &mut TxContext
  ) {
    // 1. pre-purchase checks
    pre_purchase(event, ticket_type_index, seat_index, seat_name, proof, clock);

    // 2. Create a new ticket
    // 3. post-purchase updates
    // post_purchase();
  }
}
