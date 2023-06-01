module ticketland::secondary_market {
  use sui::object::{Self, UID};
  use sui::tx_context::{TxContext, sender};
  use sui::transfer::{share_object, public_transfer};
  use std::type_name;
  use std::option::{Self, is_some};
  use sui::coin::{Coin, split, value, destroy_zero};
  use ticketland::price_oracle::{ExchangeRate, exchange_value};
  use ticketland::market_utils::{split_payable_amount};
  use ticketland::event_registry::{Config};
  use ticketland::event::{Event, get_resale_cap_bps, get_event_id, has_ticket_type};
  use ticketland::ticket::{
    Self, CNT, get_cnt_event_id, get_cnt_id, get_paid_amount, share_cnt,
    get_cnt_ticket_type_id,
  };

  /// Constants
  const BASIS_POINTS: u64 = 10_000;

  /// Errors
  const E_CNT_EVENT_MISMATCH: u64 = 0;
  const E_MAX_PRICE_VIOLATION: u64 = 1;
  const E_CNT_LISTING_MISMATCH: u64 = 2;
  const E_ONLY_LISTING_OWNER: u64 = 3;
  const E_ONLY_PURCHASED_TICKETS: u64 = 4;
  const E_WRONG_TICKET_TYPE: u64 = 5;
  const E_ONLY_OFFER_OWNER: u64 = 6;

  /// A shared object describing a listing
  /// The phantom COIN generic type indicates the coin this listing is being sold for. Note this is the
  /// type of T and not Coin<T>
  struct Listing<phantom COIN> has key {
    id: UID,
    /// The id CNT object that is being listed for sale
    cnt_id: address,
    /// The price the seller is listing this item for
    price: u64,
    /// The seller who created this listing
    seller: address,
  }

  /// A shared object describing an offer a buyer makes to purchase a ticket
  struct Offer<phantom T> has key {
    id: UID,
    /// The amount the buyer is willing to pay to purchase a Ticket
    price: Coin<T>,
    /// The buyer making this offer
    buyer: address,
    /// The CNT ticket type id (as address)
    ticket_type_id: address,
  }

  /// Allows the owner of the given ticket to list it for sale.
  /// The provided price must not exceed the allowed max resale cap value.
  /// The CNT is an owned object which will become shared so it can be later in the purchase_listing fun
  public entry fun list<COIN>(
    event: &Event,
    cnt: CNT,
    price: u64,
    exhange_rate: &ExchangeRate,
    ctx: &mut TxContext
  ) {
    assert!(get_event_id(event) == get_cnt_event_id(&cnt), E_CNT_EVENT_MISMATCH);
    let (coin_type, paid) = get_paid_amount(&cnt);
    assert!(is_some(&coin_type), E_ONLY_PURCHASED_TICKETS);

    let listing_coin_type = type_name::into_string(type_name::get<COIN>());
    // get the correct exchange rate. If Ticket was purchased in Coin0 and we want to list in Coin1
    // then in order to verify the max resale cap we need to conver the value into Coin0
    let paid = exchange_value(
      *option::borrow(&coin_type),
      listing_coin_type,
      paid,
      exhange_rate
    );

    let max_allowed_price = paid * (BASIS_POINTS + (get_resale_cap_bps(event) as u64)) / BASIS_POINTS;
    assert!(price <= max_allowed_price, E_MAX_PRICE_VIOLATION);

    let listing = Listing<COIN> {
      id: object::new(ctx),
      cnt_id: get_cnt_id(&cnt),
      price,
      seller: sender(ctx),
    };

    // The reason we share is described in the ticket module. However, sharing is important also because
    // we want to be able to pass the CNT object into the `purchase_listing`. If the object is owned the buyer, who calls
    // the function, won't be able to pass it.
    share_cnt(cnt);
    share_object(listing);
  }

  /// Allows the onwer of the listing to cancel it
  public entry fun cancel_listing<COIN>(
    cnt: CNT,
    listing: Listing<COIN>,
    ctx: &mut TxContext,
  ) {
    let owner = sender(ctx);
    assert!(listing.seller == owner, E_ONLY_LISTING_OWNER);
    assert!(listing.cnt_id == get_cnt_id(&cnt), E_CNT_LISTING_MISMATCH);

    ticket::transfer(cnt, owner);
    drop_listing(listing);
  }

  /// Allows anyone to purchase the listing by sending the correct amount of the given coin type.
  public entry fun purchase_listing<T>(
    cnt: CNT,
    listing: Listing<T>,
    coins: &mut Coin<T>,
    config: &Config,
    ctx: &mut TxContext
  ) {
    let buyer = sender(ctx);
    let (fees, payable_amount, protocol_fee_address) = split_payable_amount<T>(coins, listing.price, config);
    
    // tranfer funds to protocol and seller
    public_transfer(split(coins, fees, ctx), protocol_fee_address);
    public_transfer(split(coins, payable_amount, ctx), listing.seller);

    // tranfer the Ticket to the buyer
    ticket::transfer(cnt, buyer);
    drop_listing(listing);
  }

  fun drop_listing<COIN>(listing: Listing<COIN>) {
    let Listing {id, cnt_id: _, price: _, seller: _} = listing;
    object::delete(id);
  }

  /// Allows anyone to creat an offer for a ticket of the given type
  public entry fun offer<T>(
    event: &Event,
    ticket_type_id: address,
    price: Coin<T>,
    ctx: &mut TxContext,
  ) {
    assert!(has_ticket_type(event, &ticket_type_id), E_WRONG_TICKET_TYPE);

    let buyer = sender(ctx);
    let offer = Offer<T> {
      id: object::new(ctx),
      price,
      buyer,
      ticket_type_id,
    };

    share_object(offer);
  }

  public entry fun cancel_offer<T>(offer: Offer<T>, ctx: &mut TxContext) {
    let owner = sender(ctx);
    let Offer {id, price, buyer, ticket_type_id: _} = offer;
    assert!(buyer == owner, E_ONLY_OFFER_OWNER);
  
    public_transfer(price, owner);
    object::delete(id);
  }

  public entry fun purchase_offer<T>(
    cnt: CNT,
    offer: Offer<T>,
    config: &Config,
    ctx: &mut TxContext
  ) {
    assert!(offer.ticket_type_id == get_cnt_ticket_type_id(&cnt), E_WRONG_TICKET_TYPE);
    
    let seller = sender(ctx);
    let Offer {id, price, buyer, ticket_type_id: _} = offer;
    let (fees, payable_amount, protocol_fee_address) = split_payable_amount<T>(&price, value(&price), config);

    // tranfer funds to protocol and seller
    public_transfer(split(&mut price, fees, ctx), protocol_fee_address);
    public_transfer(split(&mut price, payable_amount, ctx), seller);

    // tranfer the Ticket to the buyer
    ticket::transfer(cnt, buyer);

    destroy_zero(price);
    object::delete(id);
  }
}
