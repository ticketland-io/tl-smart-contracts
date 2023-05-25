module ticketland::sale_type {
  use sui::clock::{Clock};
  use ticketland::event::{Event, OrganizerCap, add_sale_type};

  struct Free has store {}
  
  struct FixedPrice has store {
    /// The actual price
    amount: u256,
  }

  struct Refundable has store {
    /// The actual price
    amount: u256,
  }

  struct EnglishAuction has store {
    /// starting price of the auction
    start_price: u256,
    /// minimum bid increment
    min_bid: u256,
  }

  struct DutchAuction has store {
    start_price: u256,
    end_price: u256,
    curve_length: u16,
    drop_interval: u16,
  }

  public entry fun add_free_sale_type(
    event: &mut Event,
    ticket_type_index: u64,
    clock: &Clock,
    _cap: &OrganizerCap,
  ) {
    add_sale_type(Free {}, event, ticket_type_index, clock);
  }

  public entry fun add_fixed_price_sale_type(
    event: &mut Event,
    ticket_type_index: u64,
    amount: u256,
    clock: &Clock,
    _cap: &OrganizerCap,
  ) {
    add_sale_type(FixedPrice {amount}, event, ticket_type_index, clock);
  }

  public entry fun add_refundable_sale_type(
    event: &mut Event,
    ticket_type_index: u64,
    amount: u256,
    clock: &Clock,
    _cap: &OrganizerCap,
  ) {
    add_sale_type(Refundable {amount}, event, ticket_type_index, clock);
  }

  public entry fun add_english_auction_sale_type(
    event: &mut Event,
    ticket_type_index: u64,
    start_price: u256,
    min_bid: u256,
    clock: &Clock,
    _cap: &OrganizerCap,
  ) {
    let sale_type = EnglishAuction {start_price, min_bid};
    add_sale_type(sale_type, event, ticket_type_index, clock);
  }

  public entry fun add_dutch_auction_sale_type(
    event: &mut Event,
    ticket_type_index: u64,
    start_price: u256,
    end_price: u256,
    curve_length: u16,
    drop_interval: u16,
    clock: &Clock,
    _cap: &OrganizerCap,
  ) {
    let sale_type = DutchAuction {start_price, end_price, curve_length, drop_interval};
    add_sale_type(sale_type, event, ticket_type_index, clock);
  }
}
