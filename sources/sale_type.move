module ticketland::sale_type {
  struct Free has store {}
  
  friend ticketland::event;

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

  public(friend) fun create_free(): Free {
    Free {}
  }

  public(friend) fun create_fixed_price(amount: u256): FixedPrice {
    FixedPrice {amount}
  }

  public(friend) fun Create_refundable(amount: u256): Refundable {
    Refundable {amount}
  }

  public(friend) fun create_english_auction(start_price: u256, min_bid: u256): EnglishAuction {
    EnglishAuction {start_price, min_bid}
  }


  public(friend) fun create_dutch_auction(
    start_price: u256,
    end_price: u256,
    curve_length: u16,
    drop_interval: u16,
    ): DutchAuction {
    DutchAuction {start_price, end_price, curve_length, drop_interval}
  }
}
