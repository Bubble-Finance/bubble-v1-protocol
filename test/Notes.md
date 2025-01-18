## Audit Notes

1. InitializeConstructorArgs
   @audit-note contract InitializeOracle is a mock contract of pyth protocol.
   every pyth function go there.
   @audit-note every token should be whiteListed for raffles.
   wNomad native is whiteListed by default in the deployment.

2. InitialConditionsTest

   function test_transfersERC20orNativeBetweenUsers() public {
   // @audit-note TODO
   }

3. FactoryDeployPool
   // @audit-high The protocol need a mechanism to move the funds in case of is_locked is activate.
   // \***\*\*\*\*\*\*** Because the token is malicioius.
   // \***\*\*\*\*\*\*** Because the pool/pools is/are under attack.

4. FactoryGeters
   // **\* @audit-check The pair is not set but the function returns 0.3%
   // \*\*\*\***\*\***\*\*\*\*** Could be ok, as, if the pair is not set, it is created with the firs deposit.
   // **_ @audit-check Every token is supported by default.
   // _** That's include ERC777,fake and dangerous tokens....

5. FactoryOwnershipFeeBlackList
   // @audit-note Consider a 2 factor transferOwnership.=> we will transfer to a contract so it is not posible.
   // \*\*\* dev team reported that it is not possible as it will be transfer to a contract.
   // 3. setProtocolTeamMultisig()
   // @audit-note Consider also 2 factor transfer ProtocolTeamMultisig => we will transfer to a contract so it is not posible.

6. RouterAddLiquidity
   // @audit-low Small amount, 1000 (0,0...1), get trapped in address(1) as expected.
   // \***\*\*\*\*\*** No withdraw function but reported.
   // @audit-note Protocol does not accept tokenA = 0 but accept tokenA = 1 (0.0000..01)

7. RouterSwapERC20Tokens
   // 6. check the swap, not the formula yet @audit-note
   // - @audit-note check this error if approve ADD\*100k

   - ailing tests:
     \_ Encountered 1 failing test in test/unit/RouterSwapERC20Tokens.t.sol:RouterSwapERC20Tokens \* [FAIL. Reason: MonadexV1Router\_\_ExcessiveInputAmount(40080160320641282565131 [4.008e22], 10000000000000000000000 [1e22])] test_swapwBTCToObtain10K_DAI() (gas: 3018974)

8. RouterSwapNative
   // CHECK native contract
   // @audit-note This path does not work:
   // path[0] = s_wNative;
   // path[1] = address(DAI);
   // @audit-note wNative withdraw is failing. Review
   // ****\*\*\***** in addition, review wMonad contract how they will do withdraws as eth use transfer.
