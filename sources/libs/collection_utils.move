module ticketland::collection_utils {
  use std::vector;
  use std::ascii;
  
  /// Constants
  const EQUAL: u8 = 0;
  const BIGGER: u8 = 1;
  const SMALLER: u8 = 2;

  /// Errors
  const E_LENGTH_INVALID: u64 = 1;

  public fun compare_ascii_strings(a: &ascii::String, b: &ascii::String): u8 {
    compare_vector(ascii::as_bytes(a), ascii::as_bytes(b))
  }

  public fun compare_vector(a: &vector<u8>, b: &vector<u8>): u8 {
    let len = vector::length(a);
    let i = 0;
    assert!(vector::length(b) == len, E_LENGTH_INVALID);

    while(i < len){
      if(*vector::borrow(a, i) > *vector::borrow(b, i)) {
        return BIGGER
      };

      if(*vector::borrow(a, i) < *vector::borrow(b, i)) {
        return SMALLER
      };

      i = i + 1;
    };

    EQUAL
  }

  // It will first sort the string and the concat
  public fun concat_ascii_strings(a: ascii::String, b: ascii::String): ascii::String {
    let (a, b) = if(compare_ascii_strings(&a, &b) == SMALLER) (a, b) else (b, a);

    let vec_str = ascii::into_bytes(a);
    vector::append(&mut vec_str, ascii::into_bytes(b));
    
    ascii::string(vec_str)
  }
}
