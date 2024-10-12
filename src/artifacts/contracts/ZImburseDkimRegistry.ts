
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
  type UnencryptedL2Log,
  type Wallet,
  type WrappedFieldLike,
} from '@aztec/aztec.js';
import ZImburseDkimRegistryContractArtifactJson from './ZImburseDkimRegistry.json' assert { type: 'json' };
//@ts-ignore
//@ts-ignore
//@ts-ignore
export const ZImburseDkimRegistryContractArtifact = loadContractArtifact(ZImburseDkimRegistryContractArtifactJson as NoirCompiledContract);


      export type DKIMKeyRegistered = {
        dkim_key_hash: FieldLike
verifier_id: FieldLike
      }
    

/**
 * Type-safe interface for contract ZImburseDkimRegistry;
 */
export class ZImburseDkimRegistryContract extends ContractBase {
  
  private constructor(
    instance: ContractInstanceWithAddress,
    wallet: Wallet,
  ) {
    super(instance, ZImburseDkimRegistryContractArtifact, wallet);
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
    return Contract.at(address, ZImburseDkimRegistryContract.artifact, wallet) as Promise<ZImburseDkimRegistryContract>;
  }

  
  /**
   * Creates a tx to deploy a new instance of this contract.
   */
  public static deploy(wallet: Wallet, verifier_ids: FieldLike[], dkim_key_hashes: FieldLike[]) {
    return new DeployMethod<ZImburseDkimRegistryContract>(Fr.ZERO, wallet, ZImburseDkimRegistryContractArtifact, ZImburseDkimRegistryContract.at, Array.from(arguments).slice(1));
  }

  /**
   * Creates a tx to deploy a new instance of this contract using the specified public keys hash to derive the address.
   */
  public static deployWithPublicKeysHash(publicKeysHash: Fr, wallet: Wallet, verifier_ids: FieldLike[], dkim_key_hashes: FieldLike[]) {
    return new DeployMethod<ZImburseDkimRegistryContract>(publicKeysHash, wallet, ZImburseDkimRegistryContractArtifact, ZImburseDkimRegistryContract.at, Array.from(arguments).slice(2));
  }

  /**
   * Creates a tx to deploy a new instance of this contract using the specified constructor method.
   */
  public static deployWithOpts<M extends keyof ZImburseDkimRegistryContract['methods']>(
    opts: { publicKeysHash?: Fr; method?: M; wallet: Wallet },
    ...args: Parameters<ZImburseDkimRegistryContract['methods'][M]>
  ) {
    return new DeployMethod<ZImburseDkimRegistryContract>(
      opts.publicKeysHash ?? Fr.ZERO,
      opts.wallet,
      ZImburseDkimRegistryContractArtifact,
      ZImburseDkimRegistryContract.at,
      Array.from(arguments).slice(1),
      opts.method ?? 'constructor',
    );
  }
  

  
  /**
   * Returns this contract's artifact.
   */
  public static get artifact(): ContractArtifact {
    return ZImburseDkimRegistryContractArtifact;
  }
  

  public static get storage(): ContractStorageLayout<'admin' | 'dkim_registry'> {
      return {
        admin: {
      slot: new Fr(1n),
    },
dkim_registry: {
      slot: new Fr(2n),
    }
      } as ContractStorageLayout<'admin' | 'dkim_registry'>;
    }
    

  

  /** Type-safe wrappers for the public methods exposed by the contract. */
  public declare methods: {
    
    /** check_dkim_key_hash_private(dkim_key_hash: field) */
    check_dkim_key_hash_private: ((dkim_key_hash: FieldLike) => ContractFunctionInteraction) & Pick<ContractMethod, 'selector'>;

    /** check_dkim_key_hash_public(dkim_key_hash: field) */
    check_dkim_key_hash_public: ((dkim_key_hash: FieldLike) => ContractFunctionInteraction) & Pick<ContractMethod, 'selector'>;

    /** compute_note_hash_and_optionally_a_nullifier(contract_address: struct, nonce: field, storage_slot: field, note_type_id: field, compute_nullifier: boolean, serialized_note: array) */
    compute_note_hash_and_optionally_a_nullifier: ((contract_address: AztecAddressLike, nonce: FieldLike, storage_slot: FieldLike, note_type_id: FieldLike, compute_nullifier: boolean, serialized_note: FieldLike[]) => ContractFunctionInteraction) & Pick<ContractMethod, 'selector'>;

    /** constructor(verifier_ids: array, dkim_key_hashes: array) */
    constructor: ((verifier_ids: FieldLike[], dkim_key_hashes: FieldLike[]) => ContractFunctionInteraction) & Pick<ContractMethod, 'selector'>;

    /** public_dispatch(selector: field) */
    public_dispatch: ((selector: FieldLike) => ContractFunctionInteraction) & Pick<ContractMethod, 'selector'>;

    /** register_dkim(verifier_id: field, dkim_key_hash: field) */
    register_dkim: ((verifier_id: FieldLike, dkim_key_hash: FieldLike) => ContractFunctionInteraction) & Pick<ContractMethod, 'selector'>;

    /** register_dkim_bulk(verifier_ids: array, dkim_key_hashes: array) */
    register_dkim_bulk: ((verifier_ids: FieldLike[], dkim_key_hashes: FieldLike[]) => ContractFunctionInteraction) & Pick<ContractMethod, 'selector'>;
  };

  
    // Partial application is chosen is to avoid the duplication of so much codegen.
    private static decodeEvent<T>(
      eventSelector: EventSelector,
      eventType: AbiType,
    ): (payload: L1EventPayload | UnencryptedL2Log | undefined) => T | undefined {
      return (payload: L1EventPayload | UnencryptedL2Log | undefined): T | undefined => {
        if (payload === undefined) {
          return undefined;
        }

        if (payload instanceof L1EventPayload) {
          if (!eventSelector.equals(payload.eventTypeId)) {
            return undefined;
          }
          return decodeFromAbi([eventType], payload.event.items) as T;
        } else {
          let items = [];
          for (let i = 0; i < payload.data.length; i += 32) {
            items.push(new Fr(payload.data.subarray(i, i + 32)));
          }

          return decodeFromAbi([eventType], items) as T;
        }
      };
    }

    public static get events(): { DKIMKeyRegistered: {decode: (payload: L1EventPayload | UnencryptedL2Log | undefined) => DKIMKeyRegistered | undefined, eventSelector: EventSelector, fieldNames: string[] } } {
    return {
      DKIMKeyRegistered: {
        decode: this.decodeEvent(EventSelector.fromSignature('DKIMKeyRegistered(Field,Field)'), {
    "fields": [
        {
            "name": "dkim_key_hash",
            "type": {
                "kind": "field"
            }
        },
        {
            "name": "verifier_id",
            "type": {
                "kind": "field"
            }
        }
    ],
    "kind": "struct",
    "path": "ZImburseDkimRegistry::DKIMKeyRegistered"
}),
        eventSelector: EventSelector.fromSignature('DKIMKeyRegistered(Field,Field)'),
        fieldNames: ["dkim_key_hash","verifier_id"],
      }
    };
  }
  
}