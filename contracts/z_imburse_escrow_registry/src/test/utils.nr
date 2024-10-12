use dep::aztec::test::helpers::{cheatcodes, test_environment::TestEnvironment};
use dep::aztec::prelude::AztecAddress;
use dep::token::Token;
use dep::aztec::oracle::get_contract_instance::get_contract_instance;
use dep::z_imburse_dkim_registry::{ZImburseDkimRegistry, receipt_verifier_id};
use dep::z_imburse_escrow::ZImburseEscrow;
use crate::ZImburseEscrowRegistry;

// todo: add to codegen script
global LINODE_DKIM_KEY_HASHES = [
    712519596095629255109872801235039358170201760830784122426677669165598881666,
    13237475223415264171236793537996660854520436521041792787101330803844432479710,
    20936064893934607784344562415788497975298742600910573935943087868729550721732,
    0
];

global ESCROW_NAME = "Escrow\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0";

global USERNAME_ALICE = "alice\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0";
global USERNAME_BOB =   "bob\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0";

global USDC_NAME = "Aztec USDC\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0";
global USDC_SYMBOL = "USDC.e\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0";
global USDC_DECIMALS: u8 = 6;


/**
 * Initialize the test environment with Linode DKIM keys loaded
 * 
 * @param N - The number of escrow contracts to deploy
 * @return
 *     - The test environment
 *     - addreses of accounts [superuser, escrowAdmin, alice, bob]
 *     - addreses of contracts [token, dkimRegistry, escrowRegistry, ...escrowContracts]
 */
unconstrained pub fn setup<let N: u32>() -> (&mut TestEnvironment, [AztecAddress; 4], [AztecAddress; 3 + N]) {
    let mut env = TestEnvironment::new();
    // create 4 accounts
    let accounts: [AztecAddress; 4] = [
        env.create_account(),
        env.create_account(),
        env.create_account(),
        env.create_account()
    ];
    // deploy the token contract
    let mut contracts: [AztecAddress; 3 + N] = [AztecAddress::zero(); 3 + N];
    env.impersonate(accounts[0]);
    let token_init_call_iface = Token::interface().constructor(
        accounts[0],
        USDC_NAME,
        USDC_SYMBOL,
        USDC_DECIMALS
    );
    let token_contract = env
        .deploy("./@token_contract", "Token")
        .with_public_initializer(token_init_call_iface);
    let token_address = token_contract.to_address();
    contracts[0] = token_address;
    cheatcodes::advance_blocks_by(1);
    // deploy dkim registry contract
    let linode_id = receipt_verifier_id::LINODE as Field;
    let dkim_registry_init_call_iface = ZImburseDkimRegistry::interface().constructor(
        [linode_id, linode_id, linode_id, linode_id],
        LINODE_DKIM_KEY_HASHES
    );
    let dkim_contract = env
        .deploy("./@z_imburse_dkim_registry", "ZImburseDkimRegistry")
        .with_public_initializer(dkim_registry_init_call_iface);
    let dkim_registry_address = dkim_contract.to_address();
    contracts[1] = dkim_registry_address;
    cheatcodes::advance_blocks_by(1);
    // deploy escrow registry contract
    let escrow_contract_class_id = get_escrow_contract_class_id(&mut env);
    dep::aztec::oracle::debug_log::debug_log_format("===============================================================", []);
     dep::aztec::oracle::debug_log::debug_log_format("Gotten ID {0}", [escrow_contract_class_id]);
    let escrow_registry_init_call_iface = ZImburseEscrowRegistry::interface().constructor(
        dkim_registry_address,
        token_address,
        // contract_class_id
        escrow_contract_class_id
    );
    env.impersonate(accounts[1]);
    let escrow_registry_contract = env
        .deploy_self("ZImburseEscrowRegistry")
        .with_public_initializer(escrow_registry_init_call_iface);
    let escrow_registry_address = escrow_registry_contract.to_address();
    contracts[2] = escrow_registry_address;
    cheatcodes::advance_blocks_by(1);
    // deploy as many escrow contracts as requested
    for i in 0..N {
        let escrow_init_call_iface = ZImburseEscrow::interface().constructor(
            dkim_registry_address,
            escrow_registry_address,
            token_address,
            ESCROW_NAME
        );
        let escrow_contract = env
            .deploy("./@z_imburse_escrow", "ZImburseEscrow")
            .with_public_initializer(escrow_init_call_iface);
        let escrow_address = escrow_contract.to_address();
        contracts[3 + i] = escrow_address;
        let contract_class_id = get_contract_instance(escrow_address).contract_class_id.to_field();
        dep::aztec::oracle::debug_log::debug_log_format("===============================================================", []);

        dep::aztec::oracle::debug_log::debug_log_format("Escrow {0} class id: {1}", [i as Field, contract_class_id]);
        cheatcodes::advance_blocks_by(1);
    }
    
    // return the test environment
    (
        &mut env,
        accounts,
        contracts,
    )
}

/** Hacky way of getting the contract instance ID in the TXE */
unconstrained pub fn get_escrow_contract_class_id(env: &mut TestEnvironment) -> Field {
    let escrow_init_call_iface = ZImburseEscrow::interface().constructor(
        AztecAddress::zero(),
        AztecAddress::zero(),
        AztecAddress::zero(),
        ESCROW_NAME
    );
    let escrow_contract = env
        .deploy("./@z_imburse_escrow", "ZImburseEscrow")
        .with_public_initializer(escrow_init_call_iface);
    cheatcodes::advance_blocks_by(1);    
    escrow_contract.contract_class_id.to_field()
}

/**
 * Publicly mint tokens to a recipient (basically to the escrow contract)
 *
 * @param env - The test environment
 * @param token_address - The address of the token contract
 * @param escrow_address - The address of the escrow contract
 * @param amount - The amount of tokens to mint
 */
unconstrained pub fn mint_public(
    env: &mut TestEnvironment,
    token_address: AztecAddress,
    minter: AztecAddress,
    recipient: AztecAddress,
    amount: Field
) {
    env.impersonate(minter);
    let mint_call_iface = Token::at(token_address).mint_public(recipient, amount);
    env.call_public(mint_call_iface);
    cheatcodes::advance_blocks_by(1);
}

// is this just kinda unnecessary at this level
unconstrained pub fn to_usdc_decimals(amount: Field) -> Field {
    amount * 10.pow_32(USDC_DECIMALS as Field)
}