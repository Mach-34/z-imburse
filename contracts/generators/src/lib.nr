use dep::aztec::protocol_types::point::Point;

// Set of generator points derived via `derive_generators(...)` function from noir::std used to 
// compute note hashes

global Ga1: Point = Point {
    x: 0x30426e64aee30e998c13c8ceecda3a77807dbead52bc2f3bf0eae851b4b710c1,
    y: 0x113156a068f603023240c96b4da5474667db3b8711c521c748212a15bc034ea6,
    is_infinite: false
};
global Ga2: Point = Point {
    x: 0x2825c79cc6a5cbbeef7d6a8f1b6a12b312aa338440aefeb4396148c89147c049,
    y: 0x129bfd1da54b7062d6b544e7e36b90736350f6fba01228c41c72099509f5701e,
    is_infinite: false
};
global Ga3: Point = Point {
    x: 0x0edb1e293c3ce91bfc04e3ceaa50d2c541fa9d091c72eb403efb1cfa2cb3357f,
    y: 0x1341d675fa030ece3113ad53ca34fd13b19b6e9762046734f414824c4d6ade35,
    is_infinite: false
};
global Ga4: Point = Point {
    x: 0x041223147b680850dc82e8a55a952d4df20256fe0593d949a9541ca00f0abf15,
    y: 0x0a8c72e60d0e60f5d804549d48f3044d06140b98ed717a9b532af630c1530791,
    is_infinite: false
};
global Ga5: Point = Point {
    x: 0x0e0dad2250583f2a9f0acb04ededf1701b85b0393cae753fe7e14b88af81cb52,
    y: 0x0973b02c5caac339ee4ad5dab51329920f7bf1b6a07e1dabe5df67040b300962,
    is_infinite: false
};
global Ga6: Point = Point {
    x: 0x2f3342e900e8c488a28931aae68970738fdc68afde2910de7b320c00c902087d,
    y: 0x1bf958dc63cb09d59230603a0269ae86d6f92494da244910351f1132df20fc08,
    is_infinite: false
};
global Ga7: Point = Point {
    x: 0x1c17d5c607fffaa1d5adba6491cf0fbe502b4e259d2c1e33017d746a4ceac8f8,
    y: 0x13b04c941c55ee1ea02425d54a2a75d2f4df5eeb70a29501b38805b3af60021a,
    is_infinite: false
};
global Ga8: Point = Point {
    x: 0x032b67e8d7404dd8747e89997823611e98b6ba208ffba0880a789dcc71990206,
    y: 0x08ec0ea8f0b79126a07d694c56597c124a017f3e08901ec392283914d4f44e71,
    is_infinite: false
};
global Ga9: Point = Point {
    x: 0x0a639aa108ef2abe96a81ed88ade2934d00229b4de14219a4e5e35ae3481c73d,
    y: 0x0b5ad02f7ef3b36b5fc1af4f29b9dcc271bb77576d4638c6ce6f6bd0fb61a81e,
    is_infinite: false
};
global Gslot: Point = Point {
    x: 0x2f831c86a5020056d81e37d4c5ac2046633baaeaf3ebba2cb94d0696df1e346a,
    y: 0x1293e50410fc0c4c2d3627ecda66426a579ea25d3ff7f598c61a8a931412625c,
    is_infinite: false
};

global GENERATORS: [Point; 10] = [
    Ga1,
    Ga2,
    Ga3,
    Ga4,
    Ga5,
    Ga6,
    Ga7,
    Ga8,
    Ga9,
    Gslot
];
