module ticketland::sale_type {
  struct Free {}
  
  friend ticketland::event;

  struct FixedPrice {
    /// The actual price
    amount: u256,
  }

  struct Refundable {
    /// The actual price
    amount: u256,
  }

  struct EnglishAuction {
    /// starting price of the auction
    start_price: u256,
    /// minimum bid increment
    min_bid: u256,
  }

  struct DutchAuction {
    start_price: u256,
    end_price: u256,
    curve_length: u16,
    drop_interval: u16,
  }

  public(friend) fun CreateFree(): Free {
    Free {}
  }

  public(friend) fun CreateFixedPrice(amount: u256): FixedPrice {
    FixedPrice {amount}
  }

  public(friend) fun CreateRefundable(amount: u256): Refundable {
    Refundable {amount}
  }

  public(friend) fun CreateEnglishAuction(start_price: u256, min_bid: u256): EnglishAuction {
    EnglishAuction {start_price, min_bid}
  }


  public(friend) fun CreateDutchAuction(
    start_price: u256,
    end_price: u256,
    curve_length: u16,
    drop_interval: u16,
    ): DutchAuction {
    DutchAuction {start_price, end_price, curve_length, drop_interval}
  }
}
