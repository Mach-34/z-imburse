
/* Autogenerated file, do not edit! */

/* eslint-disable */
import {
  type AbiType,
  AztecAddress,
  type AztecAddressLike,
  CompleteAddress,
  Contract,
  type ContractArtifact,
  ContractBase,
  ContractFunctionInteraction,
  type ContractInstanceWithAddress,
  type ContractMethod,
  type ContractStorageLayout,
  type ContractNotes,
  decodeFromAbi,
  DeployMethod,
  EthAddress,
  type EthAddressLike,
  EventSelector,
  type FieldLike,
  Fr,
  type FunctionSelectorLike,
  L1EventPayload,
  loadContractArtifact,
  type NoirCompiledContract,
  NoteSelector,
  Point,
  type PublicKey,
  PublicKeys,
  type UnencryptedL2Log,
  type Wallet,
  type WrappedFieldLike,
} from '@aztec/aztec.js';
import ZImburseEscrowContractArtifactJson from './ZImburseEscrow.json' assert { type: 'json' };
export const ZImburseEscrowContractArtifact = loadContractArtifact(ZImburseEscrowContractArtifactJson as NoirCompiledContract);


      export type SpotReimbursementClaimed = {
        claimant: AztecAddressLike
amount: FieldLike
verifier_id: (bigint | number)
      }
    

      export type RecurringReimbursementClaimed = {
        claimant: AztecAddressLike
amount: FieldLike
verifier_id: (bigint | number)
timestamp: FieldLike
      }
    

      export type EntitlementNullified = {
        randomness: FieldLike
      }
    

/**
 * Type-safe interface for contract ZImburseEscrow;
 */
export class ZImburseEscrowContract extends ContractBase {
  
  private constructor(
    instance: ContractInstanceWithAddress,
    wallet: Wallet,
  ) {
    super(instance, ZImburseEscrowContractArtifact, wallet);
  }
  

  
  /**
   * Creates a contract instance.
   * @param address - The deployed contract's address.
   * @param wallet - The wallet to use when interacting with the contract.
   * @returns A promise that resolves to a new Contract instance.
   */
  public static async at(
    address: AztecAddress,
    wallet: Wallet,
  ) {
    return Contract.at(address, ZImburseEscrowContract.artifact, wallet) as Promise<ZImburseEscrowContract>;
  }

  
  /**
   * Creates a tx to deploy a new instance of this contract.
   */
  public static deploy(wallet: Wallet, registry: AztecAddressLike, usdc_token: AztecAddressLike, title: string) {
    return new DeployMethod<ZImburseEscrowContract>(PublicKeys.default(), wallet, ZImburseEscrowContractArtifact, ZImburseEscrowContract.at, Array.from(arguments).slice(1));
  }

  /**
   * Creates a tx to deploy a new instance of this contract using the specified public keys hash to derive the address.
   */
  public static deployWithPublicKeys(publicKeys: PublicKeys, wallet: Wallet, registry: AztecAddressLike, usdc_token: AztecAddressLike, title: string) {
    return new DeployMethod<ZImburseEscrowContract>(publicKeys, wallet, ZImburseEscrowContractArtifact, ZImburseEscrowContract.at, Array.from(arguments).slice(2));
  }

  /**
   * Creates a tx to deploy a new instance of this contract using the specified constructor method.
   */
  public static deployWithOpts<M extends keyof ZImburseEscrowContract['methods']>(
    opts: { publicKeys?: PublicKeys; method?: M; wallet: Wallet },
    ...args: Parameters<ZImburseEscrowContract['methods'][M]>
  ) {
    return new DeployMethod<ZImburseEscrowContract>(
      opts.publicKeys ?? PublicKeys.default(),
      opts.wallet,
      ZImburseEscrowContractArtifact,
      ZImburseEscrowContract.at,
      Array.from(arguments).slice(1),
      opts.method ?? 'constructor',
    );
  }
  

  
  /**
   * Returns this contract's artifact.
   */
  public static get artifact(): ContractArtifact {
    return ZImburseEscrowContractArtifact;
  }
  

  public static get storage(): ContractStorageLayout<'definition' | 'entitlements' | 'nullifiers'> {
      return {
        definition: {
      slot: new Fr(1n),
    },
entitlements: {
      slot: new Fr(6n),
    },
nullifiers: {
      slot: new Fr(7n),
    }
      } as ContractStorageLayout<'definition' | 'entitlements' | 'nullifiers'>;
    }
    

  public static get notes(): ContractNotes<'AddressNote' | 'UintNote' | 'EntitlementNote'> {
    return {
      AddressNote: {
          id: new NoteSelector(2232136525),
        },
UintNote: {
          id: new NoteSelector(202136239),
        },
EntitlementNote: {
          id: new NoteSelector(4112046478),
        }
    } as ContractNotes<'AddressNote' | 'UintNote' | 'EntitlementNote'>;
  }
  

  /** Type-safe wrappers for the public methods exposed by the contract. */
  public declare methods: {
    
    /** compute_note_hash_and_optionally_a_nullifier(contract_address: struct, nonce: field, storage_slot: field, note_type_id: field, compute_nullifier: boolean, serialized_note: array) */
    compute_note_hash_and_optionally_a_nullifier: ((contract_address: AztecAddressLike, nonce: FieldLike, storage_slot: FieldLike, note_type_id: FieldLike, compute_nullifier: boolean, serialized_note: FieldLike[]) => ContractFunctionInteraction) & Pick<ContractMethod, 'selector'>;

    /** constructor(registry: struct, usdc_token: struct, title: string) */
    constructor: ((registry: AztecAddressLike, usdc_token: AztecAddressLike, title: string) => ContractFunctionInteraction) & Pick<ContractMethod, 'selector'>;

    /** get_admin_private() */
    get_admin_private: (() => ContractFunctionInteraction) & Pick<ContractMethod, 'selector'>;

    /** get_registration_params() */
    get_registration_params: (() => ContractFunctionInteraction) & Pick<ContractMethod, 'selector'>;

    /** get_shared_nullifier(offset: integer, scope: struct, recipient: struct, verifier_id: integer, spot: boolean) */
    get_shared_nullifier: ((offset: (bigint | number), scope: AztecAddressLike, recipient: AztecAddressLike, verifier_id: (bigint | number), spot: boolean) => ContractFunctionInteraction) & Pick<ContractMethod, 'selector'>;

    /** get_title() */
    get_title: (() => ContractFunctionInteraction) & Pick<ContractMethod, 'selector'>;

    /** give_recurring_entitlement(recipient: struct, amount: field, verifier_id: integer) */
    give_recurring_entitlement: ((recipient: AztecAddressLike, amount: FieldLike, verifier_id: (bigint | number)) => ContractFunctionInteraction) & Pick<ContractMethod, 'selector'>;

    /** give_spot_entitlement(recipient: struct, amount: field, verifier_id: integer, date_start: integer, date_end: integer, destination: string) */
    give_spot_entitlement: ((recipient: AztecAddressLike, amount: FieldLike, verifier_id: (bigint | number), date_start: (bigint | number), date_end: (bigint | number), destination: string) => ContractFunctionInteraction) & Pick<ContractMethod, 'selector'>;

    /** nullify_entitlement(entropy_values: array) */
    nullify_entitlement: ((entropy_values: FieldLike[]) => ContractFunctionInteraction) & Pick<ContractMethod, 'selector'>;

    /** public_dispatch(selector: field) */
    public_dispatch: ((selector: FieldLike) => ContractFunctionInteraction) & Pick<ContractMethod, 'selector'>;

    /** reimburse_linode_recurring(email_receipt_inputs: struct) */
    reimburse_linode_recurring: ((email_receipt_inputs: { header: (bigint | number)[], header_length: (bigint | number), pubkey_modulus: FieldLike[], pubkey_redc: FieldLike[], signature: FieldLike[], dkim_header_sequence: { index: (bigint | number), length: (bigint | number) }, body: (bigint | number)[], body_length: (bigint | number), body_hash_index: (bigint | number), from_index: (bigint | number), subject_index: (bigint | number), amount_index: (bigint | number), date_index: (bigint | number), receipt_id_length: (bigint | number) }) => ContractFunctionInteraction) & Pick<ContractMethod, 'selector'>;

    /** reimburse_linode_spot(email_receipt_inputs: struct) */
    reimburse_linode_spot: ((email_receipt_inputs: { header: (bigint | number)[], header_length: (bigint | number), pubkey_modulus: FieldLike[], pubkey_redc: FieldLike[], signature: FieldLike[], dkim_header_sequence: { index: (bigint | number), length: (bigint | number) }, body: (bigint | number)[], body_length: (bigint | number), body_hash_index: (bigint | number), from_index: (bigint | number), subject_index: (bigint | number), amount_index: (bigint | number), date_index: (bigint | number), receipt_id_length: (bigint | number) }) => ContractFunctionInteraction) & Pick<ContractMethod, 'selector'>;

    /** reimburse_united_spot(email_inputs: struct, amount_to_date_length: integer, remaining_length: integer, actual_length: integer) */
    reimburse_united_spot: ((email_inputs: { header: (bigint | number)[], header_length: (bigint | number), pubkey_modulus: FieldLike[], pubkey_redc: FieldLike[], signature: FieldLike[], dkim_header_sequence: { index: (bigint | number), length: (bigint | number) }, body_hash_index: (bigint | number), from_index: (bigint | number), subject_index: (bigint | number), amount_sequence: { index: (bigint | number), length: (bigint | number) }, date_sequence: { index: (bigint | number), length: (bigint | number) }, airport_sequence: { index: (bigint | number), length: (bigint | number) }, partial_body_hash: (bigint | number)[], body_amount_selection: (bigint | number)[], partial_body_hash_date: (bigint | number)[], body_date_selection: (bigint | number)[] }, amount_to_date_length: (bigint | number), remaining_length: (bigint | number), actual_length: (bigint | number)) => ContractFunctionInteraction) & Pick<ContractMethod, 'selector'>;

    /** revoke_entitlement(recipient: struct, verifier_type: integer, spot: boolean) */
    revoke_entitlement: ((recipient: AztecAddressLike, verifier_type: (bigint | number), spot: boolean) => ContractFunctionInteraction) & Pick<ContractMethod, 'selector'>;

    /** sync_notes() */
    sync_notes: (() => ContractFunctionInteraction) & Pick<ContractMethod, 'selector'>;

    /** view_entitlements(offset: integer, scope: struct, recipient: struct, verifier_id: struct, spot: struct) */
    view_entitlements: ((offset: (bigint | number), scope: AztecAddressLike, recipient: { _is_some: boolean, _value: AztecAddressLike }, verifier_id: { _is_some: boolean, _value: (bigint | number) }, spot: { _is_some: boolean, _value: boolean }) => ContractFunctionInteraction) & Pick<ContractMethod, 'selector'>;
  };

  
    public static get events(): { SpotReimbursementClaimed: {abiType: AbiType, eventSelector: EventSelector, fieldNames: string[] }, RecurringReimbursementClaimed: {abiType: AbiType, eventSelector: EventSelector, fieldNames: string[] }, EntitlementNullified: {abiType: AbiType, eventSelector: EventSelector, fieldNames: string[] } } {
    return {
      SpotReimbursementClaimed: {
        abiType: {
    "kind": "struct",
    "fields": [
        {
            "name": "claimant",
            "type": {
                "kind": "struct",
                "fields": [
                    {
                        "name": "inner",
                        "type": {
                            "kind": "field"
                        }
                    }
                ],
                "path": "address_note::aztec::protocol_types::address::aztec_address::AztecAddress"
            }
        },
        {
            "name": "amount",
            "type": {
                "kind": "field"
            }
        },
        {
            "name": "verifier_id",
            "type": {
                "kind": "integer",
                "sign": "unsigned",
                "width": 8
            }
        }
    ],
    "path": "ZImburseEscrow::SpotReimbursementClaimed"
},
        eventSelector: EventSelector.fromSignature('SpotReimbursementClaimed((Field),Field,u8)'),
        fieldNames: ["claimant","amount","verifier_id"],
      },
RecurringReimbursementClaimed: {
        abiType: {
    "kind": "struct",
    "fields": [
        {
            "name": "claimant",
            "type": {
                "kind": "struct",
                "fields": [
                    {
                        "name": "inner",
                        "type": {
                            "kind": "field"
                        }
                    }
                ],
                "path": "address_note::aztec::protocol_types::address::aztec_address::AztecAddress"
            }
        },
        {
            "name": "amount",
            "type": {
                "kind": "field"
            }
        },
        {
            "name": "verifier_id",
            "type": {
                "kind": "integer",
                "sign": "unsigned",
                "width": 8
            }
        },
        {
            "name": "timestamp",
            "type": {
                "kind": "field"
            }
        }
    ],
    "path": "ZImburseEscrow::RecurringReimbursementClaimed"
},
        eventSelector: EventSelector.fromSignature('RecurringReimbursementClaimed((Field),Field,u8,Field)'),
        fieldNames: ["claimant","amount","verifier_id","timestamp"],
      },
EntitlementNullified: {
        abiType: {
    "kind": "struct",
    "fields": [
        {
            "name": "randomness",
            "type": {
                "kind": "field"
            }
        }
    ],
    "path": "ZImburseEscrow::EntitlementNullified"
},
        eventSelector: EventSelector.fromSignature('EntitlementNullified(Field)'),
        fieldNames: ["randomness"],
      }
    };
  }
  
}
