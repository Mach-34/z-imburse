use dep::aztec::protocol_types::point::Point;
use std::hash::derive_generators;
use dep::generators::GENERATORS;

#[test]
fn test_derived_generators() {
    let generators: [Point; 10] = derive_generators("aztec_nr_generators".as_bytes(), 0);
    for i in 0..generators.len() {
        assert(generators[i] == GENERATORS[i], "Generators do not match");
    }
}
