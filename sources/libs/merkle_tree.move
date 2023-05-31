module ticketland::merkle_tree {
  use std::vector;
  use std::hash::sha3_256;
  use ticketland::collection_utils::{compare_vector};

  /// Constants
  const EQUAL: u8 = 0;
  const SMALLER: u8 = 1;

  /// Errors
  const E_VERIFICATION_FAILED: u64 = 0;


  fun hash_pair(a: vector<u8>, b: vector<u8>): vector<u8> {
    if (compare_vector(&a, &b) == SMALLER) {
      vector::append(&mut a, b);
      sha3_256(a)
    } else {
      vector::append(&mut b, a);
      sha3_256(b)
    }
  }

  public fun verify(
    root: &vector<u8>,
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
    
    assert!(compare_vector(&computed_hash, root) == EQUAL, E_VERIFICATION_FAILED);
  }
}
