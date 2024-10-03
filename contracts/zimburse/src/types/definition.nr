use dep::aztec::protocol_types::{address::AztecAddress, traits::{Serialize, Deserialize}};
use dep::compressed_string::CompressedString;

global DEFINITION_LENGTH: u32 = 4;
global TITLE_LENGTH: u32 = 60;
global TITLE_SERIALIZED_LENGTH: u32 = 2;

pub struct Definition {
    admin: AztecAddress,
    usdc: AztecAddress,
    title: CompressedString<TITLE_SERIALIZED_LENGTH, TITLE_LENGTH>
}

impl Serialize<DEFINITION_LENGTH> for Definition {
    fn serialize(self: Self) -> [Field; DEFINITION_LENGTH] {
        [self.admin.to_field(), self.usdc.to_field(), self.title.value[0], self.title.value[1]]
    }
}

impl Deserialize<DEFINITION_LENGTH> for Definition {
    fn deserialize(fields: [Field; DEFINITION_LENGTH]) -> Self {
        Definition {
            admin: AztecAddress::from_field(fields[0]),
            usdc: AztecAddress::from_field(fields[1]),
            title: CompressedString { value: [fields[2], fields[3]] }
        }
    }
}

impl Definition {
    /**
     * Create a new definition for a Z-Imburse escrow contract with the uncompressed string
     *
     * @param admin The address of the admin of the contract
     * @param usdc The address of the USDC token
     * @param title The title of the contract as a string of max length 60
     * @return The new definition
     */
    pub fn new(admin: AztecAddress, usdc: AztecAddress, title: str<TITLE_LENGTH>) -> Self {
        Definition { admin, usdc, title: CompressedString::from_string(title) }
    }

    /**
     * Return the bytes of the title to display as a string
     *
     * @return The title as a string
     */
    pub fn title_as_string(self) -> [u8; TITLE_LENGTH] {
        self.title.to_bytes()
    }
}
