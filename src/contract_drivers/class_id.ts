import { computeContractClassId, getContractClassFromArtifact } from '@aztec/circuits.js/contract';
import { ZImburseEscrowContract } from "../artifacts/contracts/index.js";

/** Returns the Class ID of the Escrow contract */
export function getEscrowContractClassID() {
    const artifact = ZImburseEscrowContract.artifact;
    const contractClass = getContractClassFromArtifact(artifact);
    return computeContractClassId(contractClass);
}