# RPS

Rock-Paper-Scissors game written in Solidity tested using Foundry.

Uses Clone-Factory setup to create game instances for each new user. Other player can register themselves with the owner of the instance and can play a new game or rematch.

## Steps to play the game

1. A player get his own game instance.
2. Any of the two players create a game on the instance setting the game bet amount.
3. Both players registers the game bet.
4. Players have the choice of withdrawing before game starts i.e. before both players have submitted their move.
5. Players start submitting the move concatenated with a password(salt).
6. Players reveal their moves, sending move and password separately to be verified by the contract.
7. In case of failure in verification, that player has to resubmit the move.
8. After both players have submitted, game result is calculated.
9. Any of the player can withdraw their winnings or bet amount, in case of ties.
10. Both players have the option to request for rematch from the opponent. Only in case of both players aggreing for rematch, the new game starts.
11. Winner has the option to request rematch with his winnings, doubling the bet amount.
12. Players can incentivize an uncooperative opponent which will lose, if a move isn't submitted or revealed in the incentive duration i.e. `1 hour`.

## Steps to test

Contracts to test:

- [RPSToken.sol](src/RPSToken.sol)
- [RPSCloneFactory.sol](src/RPSCloneFactory.sol)
- [RPSGameInstance.sol](src/RPSGameInstance.sol)

> `forge test`

Runs all the fuzz and normal tests written in `src/tests` directory.

## Security Patterns

- [commit-reveal](https://blockchain-academy.hs-mittweida.de/courses/solidity-coding-beginners-to-intermediate/lessons/solidity-11-coding-patterns/topic/commit-reveal/) pattern to prevent public data being accessible to opponents. As the contract never stores any of the players' move in clear, but only the hash of the move salted with a password only known to the player. Since players cannot change their move during the reveal phase (after they have both committed their choice), this effectively ensures that an opponent could not cheat by looking at transaction data and playing accordingly.
- [Check-Effects-Interaction](https://github.com/fravoll/solidity-patterns/blob/master/docs/checks_effects_interactions.md) to prevent malicious contract trying to hijack the control flow when transferring tokens in case of rematch.
- [Pull over Push](https://github.com/fravoll/solidity-patterns/blob/master/docs/pull_over_push.md) when a user withdraws winnings or bet amount, in case of draw.

## Acknowledgments

- [0xdavinchee's RPS](https://github.com/0xdavinchee/RockPaperScissors-test-project)
- [Foundry](https://github.com/gaknost/foundry)
- [DS-Test](https://github.com/dapphub/ds-test)
- [Openzeppelin](https://github.com/OpenZeppelin/openzeppelin-contracts)
- [Solmate](https://github.com/rari-capital/solmate)
- [FrankieIsLosts's Foundry template](https://github.com/FrankieIsLost/forge-template)
