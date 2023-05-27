module ticketland::sale_type {
  use sui::clock::{Clock};
  use std::vector;
  use sui::vec_map::{Self, VecMap};
  use ticketland::event::{Event, EventOrganizerCap, add_sale_type};
  
  /// Errors
  const E_LEN_MISMATCH: u64 = 0;

  struct Free has store {}
  
  struct FixedPrice has store {
    /// A mapping from coin type to the price in that coin.  The coin type which is defined as
    /// the id (in address format) of the CoinMetadata object that describes a Coin object
    price: VecMap<address, u256>
  }

  struct Refundable has store {
    /// The actual price
    amount: VecMap<address, u256>,
  }

  struct EnglishAuction has store {
    /// starting price of the auction
    start_price: VecMap<address, u256>,
    /// minimum bid increment
    min_bid: u256,
  }

  struct DutchAuction has store {
    start_price: VecMap<address, u256>,
    end_price: VecMap<address, u256>,
    curve_length: u16,
    drop_interval: u16,
  }

  fun create_price_vec_map(
    coin_types: vector<address>,
    amounts: vector<u256>
  ): VecMap<address, u256> {
    let len = vector::length(&coin_types);
    assert!(len == vector::length(&amounts), E_LEN_MISMATCH);

    let map = vec_map::empty();
    let i = 0;
    
    while (i < len) {
      let coin_type = vector::borow(coin_types, i);
      let amount = vector::borow(amounts, i);

      vec_map::insert(&mut map, coin_type, amount);
      i = i + 1;
    }
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
    coin_types: vector<address>,
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
    coin_types: vector<address>,
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
    coin_types: vector<address>,
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
    coin_types: vector<address>,
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

  public fun get_fixed_price_amount(coin_type: address, fixed_price: &FixedPrice): u256 {
    vec_map::get(&fixed_price.price, &coin_type)
  }
}
