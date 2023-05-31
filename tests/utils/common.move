#[test_only]
module ticketland::common_test {
  use sui::math;
  use std::debug::print;
  use std::string::{Self, utf8};
  use ticketland::num_utils::{u64_to_str, u8_to_str};

  public fun to_base(val: u64): u64 {
    val * math::pow(10, 8)
  }

  public fun print_u64(msg: vector<u8>, value: u64) {
    let msg = utf8(msg);
    let str_value = u64_to_str(value);
    string::append(&mut msg, str_value);

    print(&msg);
  }

  public fun print_u8(msg: vector<u8>, value: u8) {
    let msg = utf8(msg);
    let str_value = u8_to_str(value);
    string::append(&mut msg, str_value);

    print(&msg);
  }
}
