function makeMonthLookupTable(): number[] {
  const months = [
    "Jan",
    "jan",
    "Feb",
    "feb",
    "Mar",
    "mar",
    "Apr",
    "apr",
    "May",
    "may",
    "Jun",
    "jun",
    "Jul",
    "jul",
    "Aug",
    "aug",
    "Sep",
    "sep",
    "Oct",
    "oct",
    "Nov",
    "nov",
    "Dec",
    "dec",
  ];
  //   const months = [
  //     "Jan",
  //     "Feb",
  //     "Mar",
  //     "Apr",
  //     "May",
  //     "Jun",
  //     "Jul",
  //     "Aug",
  //     "Sep",
  //     "Oct",
  //     "Nov",
  //     "Dec",
  //   ];
  //   const months = [
  //     "jan",
  //     "feb",
  //     "mar",
  //     "apr",
  //     "may",
  //     "jun",
  //     "jul",
  //     "aug",
  //     "sep",
  //     "oct",
  //     "nov",
  //     "dec",
  //   ];
  const utf8Encoder = new TextEncoder();
  const indexes = [];
  const indexSet = new Set();
  for (const month of months) {
    // Get the UTF-8 encoded bytes for the current month
    const utf8Bytes = utf8Encoder.encode(month);

    // Calculate the sum of UTF-8 bytes
    let byteSum = 0;
    // byteSum += utf8Bytes[0] * 2;
    // byteSum -= utf8Bytes[1];
    // byteSum += utf8Bytes[2];

    for (let i = 0; i < utf8Bytes.length; i++) {
      byteSum += utf8Bytes[i];
      //   if (i == 0) {
      //     byteSum += utf8Bytes[i] * 3;
      //   } else {
      //     byteSum -= utf8Bytes[i];
      //   }
    }
    // byteSum += 25;

    // Store the byte sum in the monthSums object
    indexes.push(byteSum);
    if (indexSet.has(byteSum)) {
      console.log(
        `Duplicate found: The sum of UTF-8 bytes for month "${month}" is equal to another month's sum (${byteSum}).`
      );
    } else {
      indexSet.add(byteSum);
    }
  }
  return indexes;
}

console.log(makeMonthLookupTable());
