/// This includes the basic type of sales such as Free, Refundable and Fixed price sale
module ticketland::basic_sale {
  use sui::tx_context::{TxContext};
  use std::string::{String};
  use sui::transfer::{public_transfer};
  use std::type_name;
  use sui::coin::{Coin, value, split};
  use ticketland::ticket::{Self};
  use ticketland::num_utils::{u64_to_str};
  use ticketland::event::{get_event_creator};
  use ticketland::event_registry::{Config, get_protocol_info};
  use ticketland::sale_type::{FixedPrice, get_fixed_price_amount};
  use ticketland::event::{
    Event, get_ticket_type, get_event_id, get_offchain_event_id, get_ticket_type_id, get_sale_type,
  };

  friend ticketland::primary_market;

  /// Constants
  const BASIS_POINTS: u64 = 10_000;

  /// Errors
  const E_INSUFFICIENT_BALANCE: u64 = 0;

  public(friend) entry fun free_sale(
    event: &Event,
    ticket_type_index: u64,
    ticket_name: String,
    seat_index: u64,
    seat_name: String,
    ctx: &mut TxContext
  ): address {
    let ticket_type = get_ticket_type(event, ticket_type_index);
    let price_sold = 0;

    ticket::mint_cnt(
      get_event_id(event),
      get_ticket_type_id(ticket_type),
      get_offchain_event_id(event),
      ticket_name,
      u64_to_str(seat_index),
      seat_name,
      price_sold,
      ctx,
    )
  }

  public(friend) entry fun fixed_price<T>(
    event: &Event,
    coins: &mut Coin<T>,
    ticket_type_index: u64,
    ticket_name: String,
    seat_index: u64,
    seat_name: String,
    config: &Config,
    ctx: &mut TxContext
  ): (address, u64, u64) {
    let ticket_type = get_ticket_type(event, ticket_type_index);
    let coin_type = type_name::into_string(type_name::get<Coin<T>>());
    let price = get_fixed_price_amount(
      get_sale_type<FixedPrice>(event, ticket_type_index),
      coin_type,
    );

    assert!(value(coins) >= price, E_INSUFFICIENT_BALANCE);
    let (protocol_fee, protocol_fee_address) = get_protocol_info(config);
    let fees = (price * protocol_fee) / BASIS_POINTS;
    let payable_amount = price - fees;

    // tranfer funds
    public_transfer(split(coins, fees, ctx), protocol_fee_address);
    public_transfer(split(coins, payable_amount, ctx), get_event_creator(event));

    let cnt_id = ticket::mint_cnt(
      get_event_id(event),
      get_ticket_type_id(ticket_type),
      get_offchain_event_id(event),
      ticket_name,
      u64_to_str(seat_index),
      seat_name,
      price,
      ctx,
    );

    (cnt_id, price, fees)
  }

  public(friend) entry fun refundable<T>(
        event: &Event,
    coins: &mut Coin<T>,
    ticket_type_index: u64,
    ticket_name: String,
    seat_index: u64,
    seat_name: String,
    config: &Config,
    ctx: &mut TxContext
  ): (address, u64) {
    let ticket_type = get_ticket_type(event, ticket_type_index);
    let coin_type = type_name::into_string(type_name::get<Coin<T>>());
    let price = get_refundable_price_amount(
      get_sale_type<FixedPrice>(event, ticket_type_index),
      coin_type,
    );
  }
}
