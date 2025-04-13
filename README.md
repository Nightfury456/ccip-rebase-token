# Cross-chain Rebase Token

1. A protocol that allows user to deposit inti a vault and in return, receiver rebase tokens that represent their underlying balance
2. Rebase token -> balanceOf functions is dynamic to show the changing balance with time
   - Balance increases linearly with time
   - mint tokens to our users every time they perform an action (minting, burning, transferring, or.... bridging)
3. Interest rate
   - Individually set an interest rate for each user based on some global interest rat eof the protocol at the time the user deposits into the vault.
   - This global interest rate will decrease over time to incentivise/reward early adopters.
   - Increase token adoption.