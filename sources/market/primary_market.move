module ticketland::primary_market {
  use std::vector;
  use std::hash::sha3_256;
  use sui::clock::{Self, Clock};
  use sui::coin::{Coin};
  use sui::tx_context::{TxContext, sender};
  use std::string::{Self, String, utf8};
  use sui::event::{emit};
  use sui::object::{Self, UID};
  use sui::transfer::transfer;
  use ticketland::bitmap;
  use ticketland::merkle_tree;
  use ticketland::num_utils::{u64_to_str};
  use ticketland::event_registry::Config;
  use ticketland::basic_sale;
  use ticketland::event::{
    Event, get_ticket_type, get_ticket_type_sale_time, get_seat_range, get_seats,
    get_ticket_type_mt_root, update_seats, increment_tickets_sold,
  };

  /// Capability allowing the bearer to execute operator related tasks
  struct OperatorCap has key {id: UID}

  /// Erros
  const E_SALE_CLOSED: u64 = 0;
  const E_INVALID_SEAT_INDEX: u64 = 1;
  const E_SEAT_NOT_AVAILABLE: u64 = 2;

  // Events
  struct TicketPurchased has copy, drop {
    cnt_id: address,
    price: u64,
    fees: u64,
    buyer: address,
    sale_type: String,
  }

  /// Module initializer to be executed when this module is published by the the Sui runtime
  fun init (ctx: &mut TxContext) {
    let operator_cap = OperatorCap {
      id: object::new(ctx),
    };

    transfer(operator_cap, sender(ctx));
  }

  fun create_seat_leaf(seat_index: u64, seat_name: String): vector<u8> {
    let p1 = *string::bytes(&u64_to_str(seat_index));
    let p2 = b".";
    let p3 = string::bytes(&seat_name);
    
    vector::append(&mut p1, p2);
    vector::append(&mut p1, *p3);

    sha3_256(p1)
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

    // 2. Is seat_index within the seat range of the given ticket type
    let (from, to) = get_seat_range(ticket_type);
    assert!(seat_index >= from && seat_index <= to, E_INVALID_SEAT_INDEX);

    // 3. Check that the seat_index is available
    assert!(!bitmap::is_set(get_seats(event), seat_index), E_SEAT_NOT_AVAILABLE);

    // 3. Verify the merkle path
    let mt_root = get_ticket_type_mt_root(ticket_type);
    merkle_tree::verify(mt_root, proof, create_seat_leaf(seat_index, seat_name));
  }

  fun post_purchase(event: &mut Event, seat_index: u64) {
    update_seats(event, seat_index);
    increment_tickets_sold(event);
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

    pre_purchase(event, ticket_type_index, seat_index, seat_name, proof, clock);
    let cnt_id = basic_sale::free_sale(event, ticket_type_index, ticket_name, seat_index, seat_name, ctx);
    post_purchase(event, seat_index);

    emit(TicketPurchased {
      cnt_id,
      price: 0,
      fees: 0,
      buyer,
      sale_type: utf8(b"free"),
    });
  }

  public entry fun fixed_price<T>(
    event: &mut Event,
    coins: &mut Coin<T>,
    ticket_type_index: u64,
    ticket_name: String,
    seat_index: u64,
    seat_name: String,
    proof: vector<vector<u8>>,
    config: &Config,
    clock: &Clock,
    ctx: &mut TxContext
  ) {
    let buyer = sender(ctx);

    pre_purchase(event, ticket_type_index, seat_index, seat_name, proof, clock);
    let (cnt_id, price, fees) = basic_sale::fixed_price(
      event,
      coins,
      ticket_type_index,
      ticket_name,
      seat_index,
      seat_name,
      config,
      ctx,
    );
    post_purchase(event, seat_index);

    emit(TicketPurchased {
      cnt_id,
      price,
      fees,
      buyer,
      sale_type: utf8(b"fixed_price"),
    });
  }

  public entry fun fixed_price_operator(
    _op_cap: &OperatorCap,
    buyer: address,
    event: &mut Event,
    ticket_type_index: u64,
    ticket_name: String,
    seat_index: u64,
    seat_name: String,
    proof: vector<vector<u8>>,
    clock: &Clock,
    ctx: &mut TxContext
  ) {
    pre_purchase(event, ticket_type_index, seat_index, seat_name, proof, clock);
    let cnt_id = basic_sale::fixed_price_operator(
      event,
      ticket_type_index,
      ticket_name,
      seat_index,
      seat_name,
      buyer,
      ctx,
    );
    post_purchase(event, seat_index);

    emit(TicketPurchased {
      cnt_id,
      price: 0,
      fees: 0,
      buyer,
      sale_type: utf8(b"fixed_price_operator"),
    });
  }

  public entry fun refundable<T>(
    event: &mut Event,
    coins: &mut Coin<T>,
    ticket_type_index: u64,
    ticket_name: String,
    seat_index: u64,
    seat_name: String,
    proof: vector<vector<u8>>,
    clock: &Clock,
    ctx: &mut TxContext
  ) {
    let buyer = sender(ctx);

    pre_purchase(event, ticket_type_index, seat_index, seat_name, proof, clock);
    let (cnt_id, price) = basic_sale::refundable(
      event,
      coins,
      ticket_type_index,
      ticket_name,
      seat_index,
      seat_name,
      ctx,
    );
    post_purchase(event, seat_index);

    emit(TicketPurchased {
      cnt_id,
      price,
      fees: 0,
      buyer,
      sale_type: utf8(b"refundable"),
    });
  }
}
