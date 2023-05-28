module ticketland::secondary_market {
  use sui::object::{Self, UID};
  use sui::tx_context::{TxContext, sender};
  use sui::transfer::{share_object};
  use sui::coin::{Coin};
  use sui::vec_map::{Self, VecMap};
  use ticketland::event::{Event, get_resale_cap_bps, get_event_id};
  use ticketland::ticket::{Self, CNT, get_cnt_event_id, get_cnt_id, get_paid_amount, share_cnt};

  /// Constants
  const BASIS_POINTS: u64 = 10_000;

  /// Errors
  const E_CNT_EVENT_MISMATCH: u64 = 0;
  const E_MAX_PRICE_VIOLATION: u64 = 1;
  const E_CNT_LISTING_MISMATCH: u64 = 2;
  const E_ONLY_LISTING_OWNER: u64 = 3;
  
  /// A shared object describing a listing
  /// The phantom Listing generic type indicates the coin this listing is being sold for
  struct Listing has key {
    id: UID,
    /// The id CNT object that is being listed for sale
    cnt_id: address,
    /// The price the seller is listing this item for
    price: u64,
    /// The seller who created this listing
    seller: address,
  }

  /// A shared object describing an offer a buyer makes to purchase a ticket
  struct Offer<T> has key {
    id: UID,
    /// The amount the buyer is willing to pay to purchase a Ticket
    price: Coin<T>,
    /// The buyer making this offer
    buyer: address,
    /// The index of the ticket type a buyer is willing to purchase
    ticket_type_index: u64,
  }

  /// Allows the owner of the given ticket to list it for sale.
  /// The provided price must not exceed the allowed max resale cap value.
  /// The CNT is an owned object which will become shared so it can be later in the purchase_listing fun
  public entry fun list(
    event: &Event,
    cnt: CNT,
    price: u64,
    ctx: &mut TxContext
  ) {
    assert!(get_event_id(event) == get_cnt_event_id(&cnt), E_CNT_EVENT_MISMATCH);
    let max_allowed_price = (get_paid_amount(&cnt) * (get_resale_cap_bps(event) as u64)) / BASIS_POINTS;
    assert!(price <= max_allowed_price, E_MAX_PRICE_VIOLATION);

    let listing = Listing<COIN> {
      id: object::new(ctx),
      cnt_id: get_cnt_id(&cnt),
      price,
      seller: sender(ctx),
    };

    // The reason we share is described in the ticket module. However, sharing is important also because
    // we want to be able to pass the CNT object into the `purchase_listing`. If the object is owned the buyer, who calls
    // the function won't be able to pass it.
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

    drop_listing(listing);
    ticket::transfer(cnt, owner);
  }

  /// Allows anyone to purchase the listing by sending the correct amount of the given coin type.
  public entry fun purchase_listing(cnt: CNT, ctx: &mut TxContext) {
    ticket::transfer(cnt, sender(ctx))
  }

  fun drop_listing<COIN>(listing: Listing<COIN>) {
    let Listing {id, cnt_id: _, price: _, seller: _} = listing;
    object::delete(id);
  }

  public entry fun offer() {

  }

  public entry fun cancel_offer() {
    
  }

  public entry fun purchase_offer() {
    
  }
}
