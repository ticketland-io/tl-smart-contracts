module ticketland::common_test {
  use sui::math;

  public fun to_base(val: u64): u64 {
    val * math::pow(10, 8)
  }
}
