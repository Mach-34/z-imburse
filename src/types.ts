
export type NoirInputs = {
    body_hash_index: string;
    header: string[];
    body: string[];
    body_length: string;
    header_length: string;
    pubkey: string[];
    pubkey_redc: string[];
    signature: string[];
}


export type LinodeInputs = {
    amount_index: number;
    amount_length: number;
    from_index: number;
    subject_index: number;
    receipt_id_length: number;
} & NoirInputs

// tuple type of redeem linode contract function params
export type RedeemLinodeInputs = [number[], number, number, number[], number, bigint[], bigint[], bigint[], number, number, number, number, number];

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