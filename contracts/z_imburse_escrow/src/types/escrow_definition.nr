use dep::aztec::protocol_types::{address::AztecAddress, traits::{Serialize, Deserialize}};
use dep::compressed_string::CompressedString;

global ESCROW_DEFINITION_LENGTH: u32 = 6;
global TITLE_LENGTH: u32 = 60;
global TITLE_SERIALIZED_LENGTH: u32 = 2;

pub struct EscrowDefinition {
    dkimRegistry: AztecAddress,
    escrowRegistry: AztecAddress,
    admin: AztecAddress,
    usdc: AztecAddress,
    title: CompressedString<TITLE_SERIALIZED_LENGTH, TITLE_LENGTH>
}

impl Serialize<ESCROW_DEFINITION_LENGTH> for EscrowDefinition {
    fn serialize(self: Self) -> [Field; ESCROW_DEFINITION_LENGTH] {
        [
            self.dkimRegistry.to_field(),
            self.escrowRegistry.to_field(),
            self.admin.to_field(),
            self.usdc.to_field(),
            self.title.value[0],
            self.title.value[1]
        ]
    }
}

impl Deserialize<ESCROW_DEFINITION_LENGTH> for EscrowDefinition {
    fn deserialize(fields: [Field; ESCROW_DEFINITION_LENGTH]) -> Self {
        EscrowDefinition {
            dkimRegistry: AztecAddress::from_field(fields[0]),
            escrowRegistry: AztecAddress::from_field(fields[1]),
            admin: AztecAddress::from_field(fields[2]),
            usdc: AztecAddress::from_field(fields[3]),
            title: CompressedString { value: [fields[4], fields[5]] }
        }
    }
}

impl EscrowDefinition {
    /**
     * Create a new definition for a Z-Imburse escrow contract with the uncompressed string
     *
     * @param dkimRegistry The address of the Z-Imburse dkim key hash registry
     * @param escrowRegistry The address of the Z-Imburse contract registry
     * @param admin The address of the admin of the contract
     * @param usdc The address of the USDC token
     * @param title The title of the contract as a string of max length 60
     * @return The new definition
     */
    pub fn new(
        dkimRegistry: AztecAddress,
        escrowRegistry: AztecAddress,
        admin: AztecAddress,
        usdc: AztecAddress,
        title: str<TITLE_LENGTH>
    ) -> Self {
        EscrowDefinition {
            dkimRegistry,
            escrowRegistry,
            admin,
            usdc,
            title: CompressedString::from_string(title)
        }
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
