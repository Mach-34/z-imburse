use dep::aztec::protocol_types::{address::AztecAddress, traits::{Serialize, Deserialize}};

global ESCROW_REGISTRY_DEFINITION_LENGTH: u32 = 4;

pub struct EscrowRegistryDefinition {
    admin: AztecAddress,
    dkim_registry: AztecAddress,
    usdc: AztecAddress,
    escrow_contract_id: Field
}

impl Serialize<ESCROW_REGISTRY_DEFINITION_LENGTH> for EscrowRegistryDefinition {
    fn serialize(self: Self) -> [Field; ESCROW_REGISTRY_DEFINITION_LENGTH] {
        [self.admin.to_field(), self.dkim_registry.to_field(), self.usdc.to_field(), self.escrow_contract_id]
    }
}

impl Deserialize<ESCROW_REGISTRY_DEFINITION_LENGTH> for EscrowRegistryDefinition {
    fn deserialize(fields: [Field; ESCROW_REGISTRY_DEFINITION_LENGTH]) -> Self {
        EscrowRegistryDefinition {
            admin: AztecAddress::from_field(fields[0]),
            dkim_registry: AztecAddress::from_field(fields[1]),
            usdc: AztecAddress::from_field(fields[2]),
            escrow_contract_id: fields[3]
        }
    }
}

impl EscrowRegistryDefinition {
    /**
     * Create a new definition for a Z-Imburse escrow registry contract
     *
     * @param admin The address of the admin of the contract
     * @param dkim_registry The address of the DKIM registry
     * @param usdc The address of the USDC token
     * @param escrow_contract_id The ID of the escrow contract
     * @return The new escrow registry definition
     */
    pub fn new(
        admin: AztecAddress,
        dkim_registry: AztecAddress,
        usdc: AztecAddress,
        escrow_contract_id: Field
    ) -> Self {
        EscrowRegistryDefinition { admin, dkim_registry, usdc, escrow_contract_id }
    }
}
 