module ticketland::sale_type {
  use sui::clock::{Clock};
  use std::vector;
  use std::ascii::String;
  use sui::vec_map::{Self, VecMap};
  use ticketland::event::{Event, EventOrganizerCap, add_sale_type};
  
  /// Errors
  const E_LEN_MISMATCH: u64 = 0;

  struct Free has store {}
  
  struct FixedPrice has store {
    /// A mapping from coin type to the price in that coin.  The coin type is the sui::type_name::TypeName
    /// of generic type T (i.e. Coin<T>)
    price: VecMap<String, u256>
  }

  struct Refundable has store {
    /// The actual price
    price: VecMap<String, u256>,
  }

  struct EnglishAuction has store {
    /// starting price of the auction
    start_price: VecMap<String, u256>,
    /// minimum bid increment
    min_bid: u256,
  }

  struct DutchAuction has store {
    start_price: VecMap<String, u256>,
    end_price: VecMap<String, u256>,
    curve_length: u16,
    drop_interval: u16,
  }

  fun create_price_vec_map(
    coin_types: vector<String>,
    amounts: vector<u256>
  ): VecMap<String, u256> {
    let len = vector::length(&coin_types);
    assert!(len == vector::length(&amounts), E_LEN_MISMATCH);

    let map = vec_map::empty();
    let i = 0;
    
    while (i < len) {
      let coin_type = *vector::borrow(&coin_types, i);
      let amount = *vector::borrow(&amounts, i);

      vec_map::insert(&mut map, coin_type, amount);
      i = i + 1;
    };

    map
  }

  public entry fun add_free_sale_type(
    event: &mut Event,
    ticket_type_index: u64,
    clock: &Clock,
    _cap: &EventOrganizerCap,
  ) {
    add_sale_type(Free {}, event, ticket_type_index, clock);
  }

  public entry fun add_fixed_price_sale_type(
    event: &mut Event,
    ticket_type_index: u64,
    coin_types: vector<String>,
    amounts: vector<u256>,
    clock: &Clock,
    _cap: &EventOrganizerCap,
  ) {
    let sale_type = FixedPrice {
      price: create_price_vec_map(coin_types, amounts),
    };

    add_sale_type(sale_type, event, ticket_type_index, clock);
  }

  public entry fun add_refundable_sale_type(
    event: &mut Event,
    ticket_type_index: u64,
    coin_types: vector<String>,
    amounts: vector<u256>,
    clock: &Clock,
    _cap: &EventOrganizerCap,
  ) {
    let sale_type = Refundable {
      price: create_price_vec_map(coin_types, amounts),
    };


    add_sale_type(sale_type, event, ticket_type_index, clock);
  }

  public entry fun add_english_auction_sale_type(
    event: &mut Event,
    ticket_type_index: u64,
    coin_types: vector<String>,
    start_prices: vector<u256>,
    min_bid: u256,
    clock: &Clock,
    _cap: &EventOrganizerCap,
  ) {
    let sale_type = EnglishAuction {
      start_price: create_price_vec_map(coin_types, start_prices),
      min_bid,
    };

    add_sale_type(sale_type, event, ticket_type_index, clock);
  }

  public entry fun add_dutch_auction_sale_type(
    event: &mut Event,
    ticket_type_index: u64,
    coin_types: vector<String>,
    start_prices: vector<u256>,
    end_prices: vector<u256>,
    curve_length: u16,
    drop_interval: u16,
    clock: &Clock,
    _cap: &EventOrganizerCap,
  ) {
    let sale_type = DutchAuction {
      start_price: create_price_vec_map(coin_types, start_prices),
      end_price: create_price_vec_map(coin_types, end_prices),
      curve_length,
      drop_interval,
    };

    add_sale_type(sale_type, event, ticket_type_index, clock);
  }

  public fun get_fixed_price_amount(fixed_price: &FixedPrice, coin_type: String): u256 {
    *vec_map::get(&fixed_price.price, &coin_type)
  }
}
