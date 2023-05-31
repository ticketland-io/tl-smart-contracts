module ticketland::num_utils {
  use std::vector;
  use std::string::{String, utf8};

  public fun u8_to_str(value: u8): String {
    if (value == 0) {
      return utf8(b"0")
    };

    let buffer = vector::empty<u8>();
    while (value != 0) {
      vector::push_back(&mut buffer, ((48 + value % 10) as u8));
      value = value / 10;
    };
    
    vector::reverse(&mut buffer);
    utf8(buffer)
  }

  public fun u32_to_str(value: u32): String {
    if (value == 0) {
      return utf8(b"0")
    };

    let buffer = vector::empty<u8>();
    while (value != 0) {
      vector::push_back(&mut buffer, ((48 + value % 10) as u8));
      value = value / 10;
    };
    
    vector::reverse(&mut buffer);
    utf8(buffer)
  }

  public fun u64_to_str(value: u64): String {
    if (value == 0) {
      return utf8(b"0")
    };

    let buffer = vector::empty<u8>();
    while (value != 0) {
      vector::push_back(&mut buffer, ((48 + value % 10) as u8));
      value = value / 10;
    };
    
    vector::reverse(&mut buffer);
    utf8(buffer)
  }
}
