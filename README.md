A test smart contract designed as an escrow mechanism for land sales managed by Aderemi Chambers. 

It handles payments in two stages: half upfront from the buyer to be able to initiate verification as satify the seller as to the former's seriousness, and the remaining half only if the buyer's chosen verifier approves the land documents as free from encumbrance. 

The contract prevents double-selling by locking funds until completion or refund, and it emits events for off-chain monitoring by the firm (e.g., to verify and register properties before being listed as legitimate for purchase). 

The Lagos State Multi-Door Courthouse plays a role as dispute resolver and is the exclusive authority empowered to allocate funds, only if disputes arises between buyer and seller. Otherwise, such power belongs to the firm.

The property is identified by a string ID (e.g., a reference from the firm's database).

Ultimately, the usefulness of this contract would be determined by integration with frontend for ease of use by clients and firms themselves.
