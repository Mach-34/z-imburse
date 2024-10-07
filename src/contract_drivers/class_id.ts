import { computeContractClassId, getContractClassFromArtifact } from '@aztec/circuits.js';
import { ZImburseEscrowContract } from "../artifacts/contracts";

/** Returns the Class ID of the Escrow contract */
export function getEscrowContractClassID() {
    const artifact = ZImburseEscrowContract.artifact;
    const contractClass = getContractClassFromArtifact(artifact);
    return computeContractClassId(contractClass);
}