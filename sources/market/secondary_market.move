module ticketland::secondary_market {
  use sui::object::{UID};
  use sui::tx_context::{TxContext, sender};
  use sui::transfer::{share_object};
  use sui::coint::{Coin};
  use ticketland::ticket::{CNT};

  /// A shared object describing a listing
  struct Listing has key {
    id: UID,
    /// The actual CNT object that will be wrapped in the listing object
    cnt: CNT,
    /// The price the seller is listing this item for
    price: u64,
    /// The seller who created this listing
    seller: address,
  }

  /// A shared object describing an offer a buyer makes to purchase a ticket
  struct Offer<T> {
    id: UID,
    /// The amount the buyer is willing to pay to purchase a Ticket
    price: Coin<T>,
    /// The buyer making this offer
    buyer: address,
    /// The index of the ticket type a buyer is willing to purchase
    ticket_type_index: u64,
  }

  public(entry) fun list(price: u64, ctx: ) {

  }

  public(entry) fun cancel_listing() {
    
  }

  public(entry) fun purchase_listing() {
    
  }

  public(entry) fun offer() {

  }

  public(entry) fun cancel_offer() {
    
  }

  public(entry) fun purchase_offer() {
    
  }
}
