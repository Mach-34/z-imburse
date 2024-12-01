import { CircuitInput } from "@zk-email/zkemail-nr";

export type AmericanAirlinesInputs = { from_index: number, subject_index: number, total_cost_indices: number[] } & CircuitInput;

export type FrontierInputs = { from_index: number, purchase_total_indices: number[], subject_index: number } & CircuitInput;

export type LinodeInputs = {
    amount_index: number;
    from_index: number;
    subject_index: number;
    date_index: number
    receipt_id_length: number;
} & CircuitInput

export type UnitedInputs = {
    from_index: number,
    subject_index: number,
    amount_sequence: SequenceParams,
    date_sequence: SequenceParams,
    airport_sequence: SequenceParams,
    partial_body_hash_date: string[],
    body_amount_selection: string[],
    body_date_selection: string[],
} & CircuitInput

// tuple type of redeem linode contract function params
export type RedeemLinodeInputs = {
    header: bigint[] | number[],
    header_length: bigint | number,
    pubkey_modulus: bigint[] | number[],
    pubkey_redc: bigint[] | number[],
    signature: bigint[] | number[],
    dkim_header_sequence: {
        index: bigint | number,
        length: bigint | number,
    },
    body: bigint[] | number[],
    body_length: bigint | number,
    body_hash_index: bigint | number,
    from_index: bigint | number,
    subject_index: bigint | number,
    amount_index: bigint | number,
    date_index: bigint | number,
    receipt_id_length: bigint | number,
};

// identity start and end of a string sequence
export type SequenceParams = {
    index: number;
    length: number;
};

// stringified SequenceParams for use in noir inputs
export type StringLocation = {
    index: string;
    length: string;
};