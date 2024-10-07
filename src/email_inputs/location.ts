import { SequenceParams } from "../types";

/**
 * Get the sequence parameters for a given span in the header
 * @param regex - the regex to match the header field
 * @param header - the header to match the regex against
 * @returns - the parameters for constraining the sequence in circuit
 */
export function getSequenceParams(
    regex: RegExp,
    header: String
): SequenceParams | null {
    const match = header.match(regex);
    if (match === null) return null;
    return { index: match.index!, length: match[0].length };
}