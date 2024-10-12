use dep::aztec::protocol_types::{address::AztecAddress, traits::{Serialize, Deserialize}};

global REGISTRY_DEFINITION_LENGTH: u32 = 3;

pub struct RegistryDefinition {
    admin: AztecAddress,
    usdc: AztecAddress,
    escrow_contract_id: Field
}

impl Serialize<REGISTRY_DEFINITION_LENGTH> for RegistryDefinition {
    fn serialize(self: Self) -> [Field; REGISTRY_DEFINITION_LENGTH] {
        [self.admin.to_field(), self.usdc.to_field(), self.escrow_contract_id]
    }
}

impl Deserialize<REGISTRY_DEFINITION_LENGTH> for RegistryDefinition {
    fn deserialize(fields: [Field; REGISTRY_DEFINITION_LENGTH]) -> Self {
        RegistryDefinition {
            admin: AztecAddress::from_field(fields[0]),
            usdc: AztecAddress::from_field(fields[1]),
            escrow_contract_id: fields[2]
        }
    }
}

impl RegistryDefinition {
    /**
     * Create a new definition for a Z-Imburse escrow registry contract
     *
     * @param admin - The address that can add dkim keys to the registry
     * @param usdc The address of the USDC token
     * @param escrow_contract_id The ID of the escrow contract
     * @return The new escrow registry definition
     */
    pub fn new(
        admin: AztecAddress,
        usdc: AztecAddress,
        escrow_contract_id: Field
    ) -> Self {
        RegistryDefinition { admin, usdc, escrow_contract_id }
    }
}
 