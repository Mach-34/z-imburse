use dep::aztec::{
    oracle::get_contract_instance::get_contract_instance,
    prelude::AztecAddress,
    test::helpers::{cheatcodes, test_environment::TestEnvironment}
};
use token::Token;
use zimburse_verifiers::constants::verifier_ids;
use z_imburse_escrow::ZImburseEscrow;
use crate::ZImburseRegistry;

// todo: add to codegen script
global LINODE_DKIM_KEY_HASHES = [
    712519596095629255109872801235039358170201760830784122426677669165598881666,
    13237475223415264171236793537996660854520436521041792787101330803844432479710,
    20936064893934607784344562415788497975298742600910573935943087868729550721732,
    0
];

// todo: make a macro to generate this
pub global ESCROW_NAMES = [
    "Escrow0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0",
    "Escrow1\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0",
    "Escrow2\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0",
    "Escrow3\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0",
    "Escrow4\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0",
    "Escrow5\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0",
    "Escrow6\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0",
    "Escrow7\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0",
    "Escrow8\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0",
    "Escrow9\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0",
    "Escrow10\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0",
    "Escrow11\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0",
    "Escrow12\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0",
    "Escrow13\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0",
    "Escrow14\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0",
    "Escrow15\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0",
];

pub global USERNAMES = [
    "user0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0",
    "user1\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0",
    "user2\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0",
    "user3\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0",
    "user4\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0",
    "user5\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0",
    "user6\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0",
    "user7\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0",
    "user8\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0",
    "user9\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0",
    "user10\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0",
    "user11\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0",
    "user12\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0",
    "user13\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0",
    "user14\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0",
    "user15\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0",
];

pub global ZERO_DESTINATION = "\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0";

global USERNAME_ALICE = "alice\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0";
global USERNAME_BOB =   "bob\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0";

global USDC_NAME = "Aztec USDC\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0";
global USDC_SYMBOL = "USDC.e\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0";
global USDC_DECIMALS: u8 = 6;

struct TestAccounts {
    superuser: AztecAddress,
    escrow_admin: AztecAddress,
    alice: AztecAddress,
    bob: AztecAddress
}

struct TestContracts<let N: u32> {
    usdc: AztecAddress,
    registry: AztecAddress,
    escrows: [AztecAddress; N]
}

/**
 * Initialize the test environment with Linode DKIM keys loaded
 * 
 * @param N - The number of escrow contracts to deploy
 * @return
 *     - The test environment
 *     - addreses of accounts [superuser, escrow_admin, alice, bob]
 *     - addreses of contracts [token, registry, ...escrows]
 */
unconstrained pub fn setup<let N: u32>() -> (&mut TestEnvironment, TestAccounts, TestContracts<N>) {
    let mut env = TestEnvironment::new();

    // create 4 accounts
    let accounts = TestAccounts {
        superuser: env.create_account(),
        escrow_admin: env.create_account(),
        alice: env.create_account(),
        bob: env.create_account()
    };

    // deploy the token contract
    let usdc_address = deploy_token_contract(&mut env, accounts.superuser);

    // deploy escrow registry contract
    let registry_address = deploy_registry_contract(&mut env, accounts.superuser, usdc_address);
    
    // deploy as many escrow contracts as requested
    let mut escrows: [AztecAddress; N] = [AztecAddress::zero(); N];
    for i in 0..N {
        escrows[i] = deploy_escrow_contract(&mut env, accounts.escrow_admin, registry_address, usdc_address, ESCROW_NAMES[i]);
    }
    
    // return setup params
    (
        &mut env,
        accounts,
        TestContracts {
            usdc: usdc_address,
            registry: registry_address,
            escrows
        }
    )
}

/**
 * Deploy a token contract
 * 
 * @param env - The test environment
 * @param deployer - The address of the account deploying the contract
 * @return The address of the deployed token contract
 */
unconstrained pub fn deploy_token_contract(
    env: &mut TestEnvironment,
    deployer: AztecAddress
) -> AztecAddress {
    env.impersonate(deployer);

    let token_init_call_iface = Token::interface().constructor(
        deployer,
        USDC_NAME,
        USDC_SYMBOL,
        USDC_DECIMALS
    );
    let token_contract = env
        .deploy("./@token_contract", "Token")
        .with_public_initializer(token_init_call_iface);

    cheatcodes::advance_blocks_by(1);

    token_contract.to_address()
}

/**
 * Deploy a registry contract
 * @dev todo: when > 4 dkim hashes, add all of them. alternatively could set a mask for which hashes to set
 * 
 * @param env - The test environment
 * @param deployer - The address of the account deploying the contract
 * @param token_address - The address of the token contract
 * @return The address of the deployed registry contract
 */
unconstrained pub fn deploy_registry_contract(
    env: &mut TestEnvironment,
    deployer: AztecAddress,
    token_address: AztecAddress,
) -> AztecAddress {
    env.impersonate(deployer);

    // get the contract class id of the escrow contract
    let escrow_contract_class_id = get_escrow_contract_class_id(env);

    // deploy the registry contract with set hashes
    let linode_id = verifier_ids::LINODE as Field;
    let escrow_registry_init_call_iface = ZImburseRegistry::interface().constructor(
        token_address,
        escrow_contract_class_id,
        [linode_id, linode_id, linode_id, linode_id],
        LINODE_DKIM_KEY_HASHES
    );
    let escrow_registry_contract = env
        .deploy_self("ZImburseRegistry")
        .with_public_initializer(escrow_registry_init_call_iface);

    cheatcodes::advance_blocks_by(1);

    escrow_registry_contract.to_address()
}

/**
 * Deploy an escrow contract
 * 
 * @param env - The test environment
 * @param deployer - The address of the account deploying the contract
 * @param registry_address - The address of the registry contract
 * @param token_address - The address of the token contract
 * @return The address of the deployed escrow contract
 */
unconstrained pub fn deploy_escrow_contract(
    env: &mut TestEnvironment,
    deployer: AztecAddress,
    registry_address: AztecAddress,
    token_address: AztecAddress,
    escrow_name: str<60>
) -> AztecAddress {
    env.impersonate(deployer);
    let escrow_init_call_iface = ZImburseEscrow::interface().constructor(
        registry_address,
        token_address,
        escrow_name
    );
    let escrow_contract = env
        .deploy("./@z_imburse_escrow", "ZImburseEscrow")
        .with_public_initializer(escrow_init_call_iface);
    cheatcodes::advance_blocks_by(1);
    escrow_contract.to_address()
}

/** Hacky way of getting the contract instance ID in the TXE */
unconstrained pub fn get_escrow_contract_class_id(env: &mut TestEnvironment) -> Field {
    let escrow_init_call_iface = ZImburseEscrow::interface().constructor(
        AztecAddress::zero(),
        AztecAddress::zero(),
        ESCROW_NAMES[0]
    );
    let escrow_contract = env
        .deploy("./@z_imburse_escrow", "ZImburseEscrow")
        .with_public_initializer(escrow_init_call_iface);
    cheatcodes::advance_blocks_by(1);    
    escrow_contract.contract_class_id.to_field()
}