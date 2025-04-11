1. the pool contract is created in 2 phases, it could be that the ‘initialize’ is not launched, e.g. lack of gas, but I have not been able to achieve this so far.
   1. also check for address collision!
2. initialize need protection against being called more than once??
3. We do not have a mechanism for monitoring tokens before they are added, so a pool can be created with a malicious token. We have the ‘lock’ but we have to create some ‘withdraw’, as for now it is a centralised protocol we can have the owner distribute according to the assets. We will see.
4. The owner can change the fees in his own way without warning. Do we add a time locker or something like that so that it is not all at once? Do we manage it on the front end?
5. getAllPools returns an array, then may be a DoS.
6. Tokens 777 works? check if breaks the formula
7. Next step: check if FOT breaks the formula.
8. We have an unchecked + blocktimestamp .. is this safe?
9. Remove all the ^ in pragmas.
10. A few zero address without check. Check all.
11. Review if the constant could be/should be variables.
12. OnlyOwner is a trusted owner so reflect it on the report.
13. There is 3 times where we are using the number 5 in factory. Check.
14. Why have we public functions instead of external?
