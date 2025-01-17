struct Datetime {
    year: u16,
    leap_years: u16,
    add_leap_day: bool,
    month: u8,
    day: u8,
    time: u32,
    offset: u16,
    subtract: bool
}

global DATETIME_LENGTH: u32 = 26;


global months = [
    "Jan".as_bytes(),
    "Feb".as_bytes(),
    "Mar".as_bytes(),
    "Apr".as_bytes(),
    "May".as_bytes(),
    "Jun".as_bytes(),
    "Jul".as_bytes(),
    "Aug".as_bytes(),
    "Sep".as_bytes(),
    "Oct".as_bytes(),
    "Nov".as_bytes(),
    "Dec".as_bytes()
];

global days_in_month = [
    31,
    28,
    31,
    30,
    31,
    30,
    31,
    31,
    30,
    31,
    30,
    31
];

pub fn parse_month(month: [u8; 3]) -> u8 {
    let mut index = 0;
    for i in 0..12 {
        if month == months[i] {
            index = i + 1;
        }
    }
    index
}

// todo: is leap year + is past feb 29th

pub fn compute_leap_years(year: u16) -> u16 {
    year / 4 - year / 100 + year / 400
}

pub fn is_number_constraint(num: u8) {
    assert(num >= 0x30);
    assert(num < 0x3A);
}

pub fn parse_year(year: [u8; 4]) -> (u16, u16) {
    // range check year
    for i in 0..year.len() {
        is_number_constraint(year[i]);
    }
    // compute year
    let mut year = (year[0] as u16 - 0x30) * 1000
        + (year[1] as u16 - 0x30) * 100
        + (year[2] as u16 - 0x30) * 10
        + year[3] as u16
        - 0x30;
    // figure out number of leap years
    let leap_years_since_0000 = compute_leap_years(year - 1);
    let start_leap_years = compute_leap_years(1970);
    let leap_years = leap_years_since_0000 - start_leap_years;
    (year, leap_years)
}

pub fn parse_time(time: [u8; 8]) -> u32 {
    // check each char
    is_number_constraint(time[0]);
    is_number_constraint(time[1]);
    assert(time[2] == 0x3A);
    is_number_constraint(time[3]);
    is_number_constraint(time[4]);
    assert(time[5] == 0x3A);
    is_number_constraint(time[6]);
    is_number_constraint(time[7]);
    // compute hours, mins, secs
    let hours = (time[0] as u32 - 0x30) * 10 + time[1] as u32 - 0x30;
    let mins = (time[3] as u32 - 0x30) * 10 + time[4] as u32 - 0x30;
    let secs = (time[6] as u32 - 0x30) * 10 + time[7] as u32 - 0x30;
    // return seconds since midnight
    hours * 3600 + mins * 60 + secs
}

pub fn parse_offset(offset: [u8; 5]) -> (u16, bool) {
    // determine whether to add or subtract
    let mut subtract = false;
    if offset[0] == 0x2D {
        subtract = true;
    } else {
        assert(offset[0] == 0x2B);
    }
    // check each char
    for i in 1..offset.len() {
        is_number_constraint(offset[i]);
    }
    // parse hours
    let hours = (offset[1] as u16 - 0x30) * 10 + offset[2] as u16 - 0x30;
    // parse mins
    let mins = (offset[3] as u16 - 0x30) * 10 + offset[4] as u16 - 0x30;
    // return seconds
    let offset = hours * 3600 + mins * 60;
    (offset, subtract)
}

pub fn parse_day(dat: [u8; 2]) -> u8 {
    // check each char
    is_number_constraint(dat[0]);
    is_number_constraint(dat[1]);
    // compute day
    (dat[0] as u8 - 0x30) * 10 + dat[1] as u8 - 0x30
}

pub fn add_leap_day(year: u16, month: u8) -> bool {
    // determine if current year is leap year
    let div_by_4 = (year % 4 == 0) as u1;
    let div_by_100 = (year % 100 != 0) as u1;
    let div_by_400 = (year % 400 == 0) as u1;
    let leap_year = div_by_4 * (1 - (1 - div_by_100) * (1 - div_by_400));
    // determine if month is past feb
    let past_feb = (month > 2) as u1;

    (leap_year * past_feb) as bool
}

pub fn parse_date_string(date_bytes: [u8; DATETIME_LENGTH]) -> Datetime {
    // check day shift and set day
    let day_shift = if date_bytes[1] == 0x20 {
        (0, [0x30, date_bytes[0]])
    } else {
        (1, [date_bytes[0], date_bytes[1]])
    };

    // parse day
    let day = parse_day(day_shift.1);

    // parse month
    let month = parse_month([date_bytes[2 + day_shift.0], date_bytes[3 + day_shift.0], date_bytes[4 + day_shift.0]]);
    assert(month != 0);

    // parse year
    let year = parse_year(
        [
        date_bytes[6 + day_shift.0],
        date_bytes[7 + day_shift.0],
        date_bytes[8 + day_shift.0],
        date_bytes[9 + day_shift.0]
    ]
    );
    // parse time
    let time = parse_time(
        [
        date_bytes[11 + day_shift.0],
        date_bytes[12 + day_shift.0],
        date_bytes[13 + day_shift.0],
        date_bytes[14 + day_shift.0],
        date_bytes[15 + day_shift.0],
        date_bytes[16 + day_shift.0],
        date_bytes[17 + day_shift.0],
        date_bytes[18 + day_shift.0]
    ]
    );
    // parse offset
    let offset = parse_offset(
        [
        date_bytes[20 + day_shift.0],
        date_bytes[21 + day_shift.0],
        date_bytes[22 + day_shift.0],
        date_bytes[23 + day_shift.0],
        date_bytes[24 + day_shift.0]
    ]
    );
    // check if leap day needs to be added
    let add_leap_day = add_leap_day(year.0, month);

    Datetime { year: year.0, leap_years: year.1, add_leap_day, month, day, time, offset: offset.0, subtract: offset.1 }
}

pub fn to_unix_month(datetime: Datetime) -> u32 {
    // get number of days in complete years
    let days_in_complete_years = (datetime.year - 1970) as u32 * 365 + datetime.leap_years as u32;
    // get number of days in current year
    let mut days_in_current_year = 0;
    for i in 0..12 {
        if i + 1 < datetime.month {
            days_in_current_year += days_in_month[i];
        }
    }
    days_in_current_year += datetime.add_leap_day as u32;
    // return total seconds since epoch (don't factor in the localized timestamp)
    (days_in_complete_years + days_in_current_year) * 86400 + datetime.time as u32
}

pub fn to_unix(datetime: Datetime) -> u32 {
    // get number of days in complete years
    let days_in_complete_years = (datetime.year - 1970) as u32 * 365 + datetime.leap_years as u32;
    // get number of days in current year
    let mut days_in_current_year = 0;
    for i in 0..12 {
        if i + 1 < datetime.month {
            days_in_current_year += days_in_month[i];
        }
    }
    days_in_current_year += (datetime.day + datetime.add_leap_day as u8) as u32;
    // total seconds since epoch
    let mut seconds_since_epoch = (days_in_complete_years + days_in_current_year) * 86400 + datetime.time as u32;
    // apply offset
    if datetime.subtract {
        seconds_since_epoch -= datetime.offset as u32;
    } else {
        seconds_since_epoch += datetime.offset as u32;
    }
    // return unix timestamp
    seconds_since_epoch
}

#[test]
fn test_main() {
    let date_string = "1 Sep 2024 23:22:12 +0400 ".as_bytes(); // padded 1
    // its off a lil bit
    // should be 1725247332
    // should be 1725333732
    let date = parse_date_string(date_string);
    let unix = to_unix(date);
    println(unix);
}
