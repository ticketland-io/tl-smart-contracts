/// This includes the basic type of sales such as Free, Refundable and Fixed price sale
module ticketland::basic_sale {
  use sui::tx_context::{TxContext};
  use std::string::{String};
  use ticketland::nft_ticket::{Self};
  use ticketland::num_utils::{u64_to_str};
  use ticketland::event::{
    Event, get_ticket_type, get_event_id, get_offchain_event_id, get_ticket_type_id,
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
}
