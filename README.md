# EqMesh – EQMT Position Token System

This repository contains the EQMT on-chain position system.

## OnChain Branch
is used to reflect the state of items when deployed to the blockchain.
the page [github.com/EqMesh/EQMT](https://github.com/EqMesh/EQMT) is used to accurately reflect the state of the published Tokens.

## OffChain Branch
is used to reflect and use the onChain dataset
the page [eqmesh.com/token](https://www.eqmesh.com/token) holds the current White-paper for reference


## Deployment (current & and history)
the current/live token and it's parents can always be checked via [contracts.json](https://app.eqmesh.com/lib/data/token/EQMT/meta/contracts.json)
this makes it easy to verify on-chain transactions even if the token has ben replaced.

## deployment (v0.2) on Ethereum Mainnet
there was a larger development gap, with the launch of EQMT 0.2 all transactions will now be run trough the token chain
- initial Production deployment of 0.2 on Ethereum Mainnet

## ToDo (to be included in the next deployment)
- add updateSanity (update sanity json to match the locally stored version for verification)
  this was removed by accident on a beta version, requires re-minting on detail changes (maybe not the worst idea)
  
- remove blanceOf (can be get by query strategies, if required, make sure it returns the proper value (currently returns just 1))
- allow deposits directly to the contract (anyone can send funds to the contract, to be distributed by a new adminFunction similar to creditEQMT but uses the token balance instead of msg.value)
- add tax definitions to prevent audits of suspecting hidden taxes
  example from goplus: https://gopluslabs.io/token-security/1/0x1e374a805e2184c55E2f3a5EC35471cfDce83b3A
- add helper function that does assign all unaccounted funds to the custom balance value (if needed)
