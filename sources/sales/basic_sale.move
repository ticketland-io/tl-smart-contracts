/// This includes the basic type of sales such as Free, Refundable and Fixed price sale
module ticketland::basic_sale {
  use sui::tx_context::{TxContext};
  use std::string::{String};
  use std::type_name;
  use sui::coin::{Coin};
  use ticketland::nft_ticket::{Self};
  use ticketland::num_utils::{u64_to_str};
  use ticketland::sale_type::{FixedPrice, get_fixed_price_amount};
  use ticketland::event::{
    Event, get_ticket_type, get_event_id, get_offchain_event_id, get_ticket_type_id, get_sale_type,
  };

  friend ticketland::primary_market;

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

    nft_ticket::mint_ticket(
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
    ctx: &mut TxContext
  ): (address, u256, u256) {
    let ticket_type = get_ticket_type(event, ticket_type_index);
    let coin_type = type_name::into_string(type_name::get<Coin<T>>());
    let amount = get_fixed_price_amount(
      get_sale_type<FixedPrice>(event, ticket_type_index),
      coin_type,
    );

    // TODO: calc fees and transfer funds from buyer to sellet and protocol recipient
    let fees = 0;

    let ticket_id = nft_ticket::mint_ticket(
      get_event_id(event),
      get_ticket_type_id(ticket_type),
      get_offchain_event_id(event),
      ticket_name,
      u64_to_str(seat_index),
      seat_name,
      amount,
      ctx,
    );

    (ticket_id, amount, fees)
  }
}
