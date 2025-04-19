## [H-1] NO SETTER FUNCTION TO CHECK THE OWNER OF THE FACTORY CONTRACT.

### Status 

finding under review and pending 

### Severity (Impact x Probability) 

Impact: Very High (4)
Probability: low (2)

### Date created: 2025, Apr 19th

### Summary / PoC
The current architecture and design of the factory contract, the protocol team in the initial stages will be the onlyOwner, governance later on will take control of this actor. according to the current code achitecture there is no function in place to make this switch. 

### Recommendations

consider having a setter function to set the `onlyOwner` from protocol team to governance. permission to this function can be given to the `onlyProtocolTeam` or `onlyOwner`.
