module ticketland::primary_market {
  use sui::object::{Self, UID, ID, uid_to_inner};
  use std::vector;
  use sui::clock::{Self, Clock};
  use sui::tx_context::{TxContext, sender};
  use std::string::{Self, String};
  use sui::event::{emit};
  use ticketland::bitmap;
  use ticketland::merkle_tree;
  use ticketland::num_utils::{u64_to_str};
  use ticketland::nft_ticket::{Self};
  use ticketland::event::{
    Event, get_ticket_type, get_ticket_type_sale_time, get_available_seats, get_seat_range, get_seats,
    get_ticket_type_mt_root, update_seats, increment_tickets_sold,
  };

  /// Erros
  const E_SALE_CLOSED: u64 = 0;
  const E_INVALID_SEAT_INDEX: u64 = 1;
  const E_NO_AVAILABLE_SEATS: u64 = 2;
  const E_SEAT_NOT_AVAILABLE: u64 = 3;

  // Events
  struct TicketPurchased has copy, drop {
    nft_ticket: ID,
    price: u32,
    buyer: address,
  }

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

  fun post_purchase(event: &mut Event, seat_index: u64) {
    update_seats(event, seat_index);
    increment_tickets_sold(event);
  }

  fun mint_ticket(
    event: &Event,
    ticket_type_index: u64,
    ticket_name: String,
    seat_index: u64,
    seat_name: String,
    ctx: &mut TxContext
  ) {
    // let pri
    // let nft_ticket = nft_ticket::mint_ticket(
    //   get_event_id(event),
    //   ticket_name,
    //   u64_to_str(seat_index),
    //   seat_name,
    //   price_sold,
    // );
  }

  public entry fun free_sale(
    event: &mut Event,
    ticket_type_index: u64,
    ticket_name: String,
    seat_index: u64,
    seat_name: String,
    proof: vector<vector<u8>>,
    clock: &Clock,
    ctx: &mut TxContext
  ) {
    let buyer = sender(ctx);

    // 1. pre-purchase checks
    pre_purchase(event, ticket_type_index, seat_index, seat_name, proof, clock);

    // 2. Create a new ticket
    mint_ticket(
      event,
      ticket_type_index,
      ticket_name,
      seat_index,
      seat_name,
      ctx,
    );

    // 3. post-purchase updates
    post_purchase(event, seat_index)

    // emit(TicketPurchased {
    //   id: uid_to_inner(&nft_tcicket.id),
    //   price:,
    //   buyer,
    // })
  }
}
