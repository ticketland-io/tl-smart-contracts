module ticketland::primary_market {
  use sui::object::{Self, UID, ID};
  use std::vector;
  use sui::clock::{Self, Clock};
  use sui::tx_context::{TxContext};
  use std::string::{Self, String};
  use ticketland::event::{
    Event, get_ticket_type, get_ticket_type_sale_time, is_ticket_type_seat,
    has_available_seats,
  };
  use ticketland::num_utils::{u32_to_str};

  /// Erros
  const E_SALE_CLOSED: u64 = 0;
  const E_INVALID_SEAT_INDEX: u64 = 1;
  const E_NO_AVAILABLE_SEATS: u64 = 2;

  fun create_seat_leaf(seat_index: u32, seat_name: String): vector<u8> {
    let p1 = *string::bytes(&u32_to_str(seat_index));
    let p2 = b".";
    let p3 = string::bytes(&seat_name);
    
    vector::append(&mut p1, p2);
    vector::append(&mut p1, *p3);

    p1
  }

  fun pre_checks(
    event: &Event,
    ticket_type_index: u64,
    seat_index: u32,
    seat_name: String,
    clock: &Clock,
  ) {
    let now = clock::timestamp_ms(clock);
    let ticket_type = get_ticket_type(event, ticket_type_index);

    // 1. Check sale time
    let (start_time, end_time) = get_ticket_type_sale_time(ticket_type);
    assert!(now >= start_time && now < end_time, E_SALE_CLOSED);

    // 2. Are there any available seats for this type of ticket
    assert!(has_available_seats(event), E_NO_AVAILABLE_SEATS);

    // 3. Is seat_index within the seat range of the given ticket type
    assert!(
      is_ticket_type_seat(ticket_type, seat_index),
      E_INVALID_SEAT_INDEX
    );

    // 3. Check that the seat_index is available
  }

  public entry fun free_sale(
    event: &Event,
    ticket_type_index: u64,
    seat_index: u32,
    seat_name: String,
    ctx: &mut TxContext
  ) {
    // 1. pre-checks: Verify the seat using merkle path verification
    // 2. Create a new ticket
    // 3. post-checks: update event capacity bitmap and other relevant fields
  }
}
