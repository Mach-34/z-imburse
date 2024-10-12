import { CircuitInput } from "@mach-34/zkemail-nr";

export type FrontierInputs = { from_index: number, subject_index: number } & CircuitInput;

export type LinodeInputs = {
    amount_index: number;
    amount_length: number;
    from_index: number;
    subject_index: number;
    date_index: number
    receipt_id_length: number;
} & CircuitInput

export type UnitedInputs = { from_index: number, purchase_summary_indices: number[], subject_index: number } & CircuitInput

// tuple type of redeem linode contract function params
export type RedeemLinodeInputs = [number[], number, number, number[], number, bigint[], bigint[], bigint[], number, number, number, number, number, number];

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