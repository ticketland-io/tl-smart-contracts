module ticketland::merkle_tree {
  use std::vector;
  use std::hash::sha3_256;

  const EQUAL: u8 = 0;
  const BIGGER: u8 = 1;
  const SMALLER: u8 = 2;

  const E_VERIFICATION_FAILED: u64 = 0;
  const E_LENGTH_INVALID: u64 = 1;

  fun compare_vector(a: &vector<u8>, b: &vector<u8>): u8 {
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

  fun hash_pair(a: vector<u8>, b: vector<u8>): vector<u8> {
    if (compare_vector(&a, &b) == SMALLER) {
      vector::append(&mut a, b);
      sha3_256(a)
    } else {
      vector::append(&mut b, a);
      sha3_256(b)
    }
  }

  public entry fun verify(
    root: vector<u8>,
    proof: vector<vector<u8>>,
    leaf: vector<u8>
  ) {
    let computed_hash = leaf;
    let i = 0;

    while (i < vector::length(&proof)) {
      let curr = vector::borrow(&proof, i);
      computed_hash = hash_pair(computed_hash, *curr);

      i = i + 1;
    };

    assert!(compare_vector(&computed_hash, &root) == EQUAL, E_VERIFICATION_FAILED);
  }
}
