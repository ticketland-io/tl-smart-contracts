module ticketland::sale_type {
  struct Free {}
  
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
}
