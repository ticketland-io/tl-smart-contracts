module ticketland::sale_type {
  use sui::clock::{Clock};
  use std::type_name;
  use ticketland::event_registry::{Config, is_coin_supported};
  use ticketland::event::{Event, EventOrganizerCap, add_sale_type};
  
  /// Errors
  const E_LEN_MISMATCH: u64 = 0;
  const E_COIN_NOT_SUPPORTED: u64 = 1;

  struct Free has store {}
  
  struct FixedPrice<phantom COIN> has store {
    price: u64,
  }

  struct Refundable<phantom COIN> has store {
    /// The actual price
    price: u64,
  }

  struct EnglishAuction<phantom COIN> has store {
    /// starting price of the auction
    start_price: u64,
    /// minimum bid increment
    min_bid: u64,
  }

  struct DutchAuction<phantom COIN> has store {
    start_price: u64,
    end_price: u64,
    curve_length: u16,
    drop_interval: u16,
  }

  fun assert_coin_supported<COIN>(config: &Config) {
    let coin_type = type_name::into_string(type_name::get<COIN>());
    assert!(is_coin_supported(config, &coin_type), E_COIN_NOT_SUPPORTED);
  }

  public entry fun add_free_sale_type(
    event: &mut Event,
    ticket_type_index: u64,
    clock: &Clock,
    _cap: &EventOrganizerCap,
  ) {
    add_sale_type(Free {}, event, ticket_type_index, clock);
  }

  public entry fun add_fixed_price_sale_type<COIN>(
    event: &mut Event,
    ticket_type_index: u64,
    price: u64,
    config: &Config,
    clock: &Clock,
    _cap: &EventOrganizerCap,
  ) {
    assert_coin_supported<COIN>(config);
    let sale_type = FixedPrice<COIN> {price};
    add_sale_type(sale_type, event, ticket_type_index, clock);
  }

  public entry fun add_refundable_sale_type<COIN>(
    event: &mut Event,
    ticket_type_index: u64,
    price: u64,
    config: &Config,
    clock: &Clock,
    _cap: &EventOrganizerCap,
  ) {
    assert_coin_supported<COIN>(config);
    let sale_type = Refundable<COIN> {price};
    add_sale_type(sale_type, event, ticket_type_index, clock);
  }

  public entry fun add_english_auction_sale_type<COIN>(
    event: &mut Event,
    ticket_type_index: u64,
    start_price: u64,
    min_bid: u64,
    config: &Config,
    clock: &Clock,
    _cap: &EventOrganizerCap,
  ) {
    assert_coin_supported<COIN>(config);
    let sale_type = EnglishAuction<COIN> {start_price, min_bid};
    add_sale_type(sale_type, event, ticket_type_index, clock);
  }

  public entry fun add_dutch_auction_sale_type<COIN>(
    event: &mut Event,
    ticket_type_index: u64,
    start_price: u64,
    end_price: u64,
    curve_length: u16,
    drop_interval: u16,
    config: &Config,
    clock: &Clock,
    _cap: &EventOrganizerCap,
  ) {
    assert_coin_supported<COIN>(config);
    let sale_type = DutchAuction<COIN> {
      start_price,
      end_price,
      curve_length,
      drop_interval,
    };

    add_sale_type(sale_type, event, ticket_type_index, clock);
  }

  public fun get_fixed_price_amount<COIN>(fixed_price: &FixedPrice<COIN>): u64 {
    fixed_price.price
  }

  public fun get_refundable_price_amount<COIN>(refundable: &Refundable<COIN>): u64 {
    refundable.price
  }
}
