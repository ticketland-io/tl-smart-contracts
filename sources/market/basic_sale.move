/// This includes the basic type of sales such as Free, Refundable and Fixed price sale
module ticketland::basic_sale {
  use sui::tx_context::{TxContext, sender};
  use std::string::{String};
  use std::option::{some, none};
  use sui::transfer::{transfer, public_transfer};
  use std::type_name;
  use sui::object::{Self, UID, delete};
  use sui::coin::{Coin, split};
  use ticketland::ticket::{Self, CNT, get_cnt_id, get_cnt_owner};
  use ticketland::num_utils::{u64_to_str};
  use ticketland::event::{get_event_creator};
  use ticketland::attendance::{Self, has_attended};
  use ticketland::market_utils::{has_enough_balance, split_payable_amount};
  use ticketland::event_registry::Config;
  use ticketland::sale_type::{
    FixedPrice, Refundable, get_fixed_price_amount, get_refundable_price_amount
  };
  use ticketland::event::{
    Event, get_ticket_type, get_event_id, get_ticket_type_id, get_sale_type,
  };

  #[test_only]
  use sui::coin::{Self};

  friend ticketland::primary_market;

  /// Constants
  const BASIS_POINTS: u64 = 10_000;

  /// Errors
  const E_DID_NOT_ATTEND: u64 = 0;
  const E_ONLY_CNT_OWNER: u64 = 1;

  // Holds the coins paid for refundable tickets
  struct Refund<phantom T> has key {
    id: UID,
    /// The CNT id
    cnt_id: address,
    /// Allows to store escrowed coins for all the supported coin types
    coins: Coin<T>,
  }

  public(friend) entry fun free_sale(
    event: &Event,
    ticket_type_index: u64,
    ticket_name: String,
    seat_index: u64,
    seat_name: String,
    ctx: &mut TxContext
  ): address {
    let ticket_type = get_ticket_type(event, ticket_type_index);
    let paid = 0;

    ticket::mint_cnt(
      get_event_id(event),
      get_ticket_type_id(ticket_type),
      ticket_name,
      u64_to_str(seat_index),
      seat_name,
      none(),
      paid,
      sender(ctx),
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
    let coin_type = type_name::into_string(type_name::get<T>());
    let price = get_fixed_price_amount(get_sale_type<FixedPrice<T>>(event, ticket_type_index));
    let (fees, payable_amount, protocol_fee_address) = split_payable_amount<T>(coins, price, config);

    // tranfer funds
    public_transfer(split(coins, fees, ctx), protocol_fee_address);
    public_transfer(split(coins, payable_amount, ctx), get_event_creator(event));

    let cnt_id = ticket::mint_cnt(
      get_event_id(event),
      get_ticket_type_id(ticket_type),
      ticket_name,
      u64_to_str(seat_index),
      seat_name,
      some(coin_type),
      price,
      sender(ctx),
      ctx,
    );

    (cnt_id, price, fees)
  }

  public(friend) entry fun fixed_price_operator(
    event: &Event,
    ticket_type_index: u64,
    ticket_name: String,
    seat_index: u64,
    seat_name: String,
    buyer: address,
    ctx: &mut TxContext
  ): address {
    let ticket_type = get_ticket_type(event, ticket_type_index);

    let cnt_id = ticket::mint_cnt(
      get_event_id(event),
      get_ticket_type_id(ticket_type),
      ticket_name,
      u64_to_str(seat_index),
      seat_name,
      none(),
      0,
      buyer,
      ctx,
    );

    cnt_id
  }

  public(friend) entry fun refundable<T>(
    event: &Event,
    coins: &mut Coin<T>,
    ticket_type_index: u64,
    ticket_name: String,
    seat_index: u64,
    seat_name: String,
    ctx: &mut TxContext,
  ): (address, u64) {
    let ticket_type = get_ticket_type(event, ticket_type_index);
    let coin_type = type_name::into_string(type_name::get<T>());
    let price = get_refundable_price_amount(
      get_sale_type<Refundable<T>>(event, ticket_type_index),
    );
    
    has_enough_balance<T>(coins, price);

    let cnt_id = ticket::mint_cnt(
      get_event_id(event),
      get_ticket_type_id(ticket_type),
      ticket_name,
      u64_to_str(seat_index),
      seat_name,
      some(coin_type),
      price,
      sender(ctx),
      ctx,
    );

    // Create a Refund object which the owner can use in the future to calim the refund after attending the event
    let refund = Refund {
      id: object::new(ctx),
      cnt_id,
      coins: split(coins, price, ctx),
    };

    transfer(refund, sender(ctx));

    (cnt_id, price)
  }

  /// Refundable tickets allow the owners who attended the event to get a refund for the money paid to buy the ticket.
  public entry fun claim_refund<T>(
    cnt: &CNT,
    config: &attendance::Config,
    refund: Refund<T>,
    ctx: &mut TxContext,
  ) {
    let owner = sender(ctx);
    assert!(get_cnt_owner(cnt) == owner, E_ONLY_CNT_OWNER);
    let cnt_id = get_cnt_id(cnt);
    assert!(has_attended(cnt_id, config), E_DID_NOT_ATTEND);
    
    // destroy object
    let Refund {id, cnt_id: _, coins} = refund;
    delete(id);

    public_transfer(coins, owner);
  }

  #[view]
  #[test_only]
  public fun get_refund_info<T>(refund: &Refund<T>): (address, u64) {
    let Refund {id: _, cnt_id, coins} = refund;
    (*cnt_id, coin::value(coins))
  }
}
