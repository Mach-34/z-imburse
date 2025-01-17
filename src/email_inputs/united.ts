import { generateEmailVerifierInputsFromDKIMResult, verifyDKIMSignature } from "@zk-email/zkemail-nr";
import { getSequenceParams } from "./location";
import { Regexes } from "../constants";
import { SequenceParams, UnitedInputs } from "../types";
import { decodeQuotedPrintable } from "../utils";
import { sign } from "crypto";

const UNITED_MAX_HEADER_LENGTH = 640;
const UNITED_MAX_BODY_LENGTH = 58560;

/**
 * Find the index of a pattern in a string that contains =\r\n sequences,
 * treating the string as if the =\r\n sequences weren't there.
 * @param {string} encodedStr - The string with =\r\n sequences
 * @param {string} pattern - The pattern to find (e.g. "<br/>")
 * @param {number} startPos - Position to start searching from (optional)
 * @returns {number} The index where the pattern starts in the encoded string, or -1 if not found
 */
const findPatternInEncodedString = (encodedStr: string, pattern: string, startPos = 0) => {
    let encodedPos = startPos;  // Position in encoded string
    let matchStart = -1;        // Start position of current match
    let matchLength = 0;        // How many characters we've matched so far

    while (encodedPos < encodedStr.length) {
        // Skip =\r\n sequence
        if (encodedStr[encodedPos] === '=' &&
            encodedPos + 2 < encodedStr.length &&
            encodedStr[encodedPos + 1] === '\r' &&
            encodedStr[encodedPos + 2] === '\n') {
            // If we're in the middle of a match, continue from after the =\r\n
            encodedPos += 3;
            continue;
        }

        // Check if current character matches next character in pattern
        if (encodedStr[encodedPos] === pattern[matchLength]) {
            // If this is the first matching character, record the start position
            if (matchLength === 0) {
                matchStart = encodedPos;
            }
            matchLength++;

            // If we've matched the entire pattern, return the start position
            if (matchLength === pattern.length) {
                return matchStart;
            }
        } else {
            // If we were in the middle of a match but hit a non-matching character,
            // restart matching from the position after where we started this match
            if (matchLength > 0) {
                encodedPos = matchStart + 1;
                matchLength = 0;
                continue;
            }
        }

        encodedPos++;
    }

    return -1;  // Pattern not found
}


const getDateSequence = (emailBody: string) => {
    const dateHtmlPrefix = findPatternInEncodedString(emailBody, '2nd bag weight and dimensions');
    const dateHtmlPostfix = findPatternInEncodedString(emailBody, '<br/>', dateHtmlPrefix);
    let endIndex = dateHtmlPostfix + 4;
    if (emailBody[endIndex] !== '>') {
        endIndex += 3;
    }
    const length = endIndex + 1 - dateHtmlPrefix;
    return { index: dateHtmlPrefix, length } as SequenceParams
}

const getDestinationAirportSequence = (emailBody: string) => {
    const dateHtmlPrefix = findPatternInEncodedString(emailBody, '2nd bag weight and dimensions');
    const dateHtmlPostfix = findPatternInEncodedString(emailBody, '<br/>', dateHtmlPrefix);
    const destinationPrefix = findPatternInEncodedString(emailBody, '<br/>', dateHtmlPostfix + 1);
    const destinationPostfix = findPatternInEncodedString(emailBody, '</td>', destinationPrefix);
    let endIndex = destinationPostfix + 4;
    if (emailBody[endIndex] !== '>') {
        endIndex += 3;
    }
    const length = endIndex + 1 - destinationPrefix;
    return { index: destinationPrefix, length } as SequenceParams
}

const getTotalSequence = (emailBody: string) => {
    const totalHtmlPrefix = findPatternInEncodedString(emailBody, 'Total:');
    const totalHtmlPostfix = findPatternInEncodedString(emailBody, 'USD', totalHtmlPrefix);
    let endIndex = totalHtmlPostfix + 4;
    if (emailBody[endIndex] !== '>') {
        endIndex += 3;
    }
    const length = endIndex + 1 - totalHtmlPrefix;
    return { index: totalHtmlPrefix, length } as SequenceParams
}

// total will always be at beginning so no need to split
const pickTotal = (oldSequence: SequenceParams): {
    sequence: SequenceParams,
    sliceSequence: SequenceParams
} => {
    const endIndex = Math.ceil((oldSequence.index + oldSequence.length) / 64) * 64;
    return {
        sequence: {
            index: oldSequence.index,
            length: oldSequence.length
        },
        sliceSequence: {
            index: 0,
            length: endIndex
        }
    }
}

const pickDateAndAirport = (oldDate: SequenceParams, oldAirport: SequenceParams): {
    dateSequence: SequenceParams,
    airportSequence: SequenceParams,
    sliceSequence: SequenceParams,
} => {
    // date will come before airport
    const startIndex = (Math.floor(oldDate.index / 64)) * 64;
    const endIndex = (Math.ceil((oldAirport.index + oldAirport.length) / 64)) * 64;
    // adjust sequences
    const dateSequence = {
        index: oldDate.index - startIndex,
        length: oldDate.length
    };
    const airportSequence = {
        index: oldAirport.index - startIndex,
        length: oldAirport.length
    };
    return {
        dateSequence,
        airportSequence,
        sliceSequence: {
            index: startIndex,
            length: endIndex
        }
    }
}

export const deferred = async (email: Buffer, inputs: UnitedInputs) => {
    // determine the actual length
    const actualLength = inputs.partial_body_real_length!;
    // 
}

/**
 * Given an email, generate the inputs for the United receipt proof
 * @param email - the United flight receipt email to generate the inputs for
 */
export const makeUnitedInputs = async (
    email: Buffer
): Promise<{inputs: UnitedInputs, deferred: any}> => {
    const dkimResult = await verifyDKIMSignature(email);
    const baseInputs = generateEmailVerifierInputsFromDKIMResult(dkimResult, {
        maxBodyLength: UNITED_MAX_BODY_LENGTH,
        maxHeadersLength: UNITED_MAX_HEADER_LENGTH,
        shaPrecomputeSelector: 'Total:'
    });
    // grab sequence params from the email
    const header = dkimResult.headers.toString();
    const fromParams = getSequenceParams(Regexes.from, header);
    if (fromParams === null) throw new Error("No 'from' field found in email");

    // extract the index and length of the subject field
    const subjectParams = getSequenceParams(Regexes.subject, header);
    if (subjectParams === null)
        throw new Error("No 'subject' field found in email");

    const partialBodyBytes = new Uint8Array(baseInputs.body!.storage.map((val: string) => Number(val)));
    const body = Buffer.from(partialBodyBytes).toString('utf8');
    const airportParams = getDestinationAirportSequence(body);
    const dateParams = getDateSequence(body);
    const totalParams = getTotalSequence(body);

    const interstitialLength = dateParams.index - (totalParams.length + totalParams.index)

    const { partial_body_hash: partial_body_hash_date } = generateEmailVerifierInputsFromDKIMResult(dkimResult, {
        maxBodyLength: UNITED_MAX_BODY_LENGTH,
        maxHeadersLength: UNITED_MAX_HEADER_LENGTH,
        shaPrecomputeSelector: '2nd bag weight and dimensions'
    });

    // reformat sequences
    const pickedTotal = pickTotal(totalParams);
    const { dateSequence, airportSequence, sliceSequence } = pickDateAndAirport(dateParams, airportParams);
    const amountSelection = baseInputs.body!.storage.slice(pickedTotal.sliceSequence.index, pickedTotal.sliceSequence.length);
    const dateSelection = baseInputs.body!.storage.slice(sliceSequence.index, sliceSequence.length);

    const inputs = {
        ...baseInputs,
        header: {
            storage: baseInputs.header.storage.fill('0', Number(baseInputs.header.len)),
            len: baseInputs.header.len
        },
        from_index: fromParams.index,
        subject_index: subjectParams.index,
        amount_sequence: pickedTotal.sequence,
        date_sequence: dateSequence,
        airport_sequence: airportSequence,
        partial_body_hash_date: partial_body_hash_date as string[],
        body_amount_selection: amountSelection,
        body_date_selection: dateSelection,
    };

    // grab remaining sequences
    // todo: fix slice sequence naming length when it is end index
    const actualLength = parseInt(inputs.partial_body_real_length!);
    const amountToDateStart = pickedTotal.sliceSequence.index + pickedTotal.sliceSequence.length;
    const amountToDateEnd = sliceSequence.index;
    const amountToDateBody = baseInputs.body!.storage.slice(amountToDateStart, amountToDateEnd);

    const remainingStart = sliceSequence.length;
    const remainingEnd = parseInt(inputs.body!.len);
    // console.log("Body s", inputs.body!.len);
    // console.log("Actual length: ", actualLength);
    // console.log("Amount to date length: ", amountToDateBody.length);
    // console.log("Amount selection length: ", amountSelection.length);
    // console.log("Date selection length: ", dateSelection.length);
    const remainingBody = baseInputs.body!.storage.slice(remainingStart, remainingEnd);

    const deferred = {
        actualLength,
        amountToDateBody,
        remainingBody
    }

    // disable body
    delete inputs.body;
    return { inputs, deferred };
};

export const toContractFriendly = (inputs: UnitedInputs) => {
    return {
        header: inputs.header.storage.map((val: string) => parseInt(val)),
        header_length: parseInt(inputs.header.len),
        pubkey_modulus: inputs.pubkey.modulus.map((val: string) => parseInt(val)),
        pubkey_redc: inputs.pubkey.redc.map((val: string) => parseInt(val)),
        signature: inputs.signature.map((val: string) => parseInt(val)),
        dkim_header_sequence: {
            index: parseInt(inputs.dkim_header_sequence.index),
            length: parseInt(inputs.dkim_header_sequence.length)
        },
        body_hash_index: parseInt(inputs.body_hash_index!),
        from_index: inputs.from_index,
        subject_index: inputs.subject_index,
        amount_sequence: inputs.amount_sequence,
        date_sequence: inputs.date_sequence,
        airport_sequence: inputs.airport_sequence,
        body_amount_selection: inputs.body_amount_selection.map((val: string) => parseInt(val)),
        partial_body_hash: inputs.partial_body_hash!.map((val: string) => parseInt(val)),
        partial_body_hash_date: inputs.partial_body_hash_date.map((val: string) => parseInt(val)),
        body_date_selection: inputs.body_date_selection.map((val: string) => parseInt(val)),
    }
}