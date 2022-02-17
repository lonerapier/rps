// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import "@openzeppelin/contracts/interfaces/IERC20.sol";

// import "@openzeppelin/contracts/proxy/utils/Initializable.sol";

contract RPSGameInstance {
    enum GameState {
        GameCreated,
        WaitingForPlayersToBet,
        WaitingForPlayersToSubmitMove,
        WaitingForPlayersToReveal,
        Finished
    }

    enum PlayerState {
        Initialized,
        Betted,
        SubmittedMove,
        Revealed,
        Rematch
    }

    struct PlayerGameData {
        bool deposited;
        bool revealed;
        PlayerState playerState;
        bytes32 move;
    }

    struct Game {
        address playerA;
        address playerB;
        address winner;
        uint256 betAmount;
        uint256 totalAmount;
        GameState state;
        PlayerGameData[2] playerGameData;
    }

    // constants
    bytes32 public constant ROCK = keccak256(abi.encodePacked(uint8(1))); // ROCK
    bytes32 public constant PAPER = keccak256(abi.encodePacked(uint8(2))); // PAPER
    bytes32 public constant SCISSORS = keccak256(abi.encodePacked(uint8(3))); // SCISSORS

    address private owner;
    Game[] public games;
    mapping(address => uint256) private gamesMapping;
    IERC20 public token;

    event GameCreated(
        uint256 gameId,
        address playerA,
        address playerB,
        uint256 betAmount
    );
    event GameStarted(uint256 gameId, address playerA, address playerB);
    event MoveSubmitted(address player, uint256 gameId, bytes32 move);
    event MoveRevealed(address player, uint256 gameId, uint8 move);
    event GameFinished(
        uint256 gameId,
        address playerA,
        address playerB,
        address winner
    );

    modifier isValidGamePlayer(uint256 _gameId, address _player) {
        require(
            _player == games[_gameId].playerA ||
                _player == games[_gameId].playerB,
            "Player is not a valid player"
        );
        _;
    }

    modifier isValidGame(uint256 _gameId) {
        require(_gameId < games.length, "Game does not exist");
        _;
    }

    function initialize(address _player, address tokenAddress) public {
        owner = _player;
        token = IERC20(tokenAddress);
    }

    function createGame(address _player, uint256 _betAmount)
        external
        returns (uint256)
    {
        require(_player != owner, "PlayerA and PlayerB different");
        require(_player != address(0), "PlayerA or PlayerB null");

        uint256 gameId = games.length;
        Game memory _game;
        _game.playerA = owner;
        _game.playerB = _player;
        _game.betAmount = _betAmount;
        _game.state = GameState.GameCreated;
        games.push(_game);

        gamesMapping[_player] = gameId;

        emit GameCreated(gameId, owner, _player, _betAmount);

        return gameId;
    }

    function register(uint256 _gameId)
        external
        isValidGame(_gameId)
        isValidGamePlayer(_gameId, msg.sender)
        returns (bool)
    {
        uint8 playerIndex = msg.sender == owner ? 0 : 1;

        require(
            games[_gameId].playerGameData[playerIndex].playerState ==
                PlayerState.Betted,
            "Player already deposited"
        );
        require(
            token.balanceOf(msg.sender) >= games[_gameId].betAmount,
            "Not enough tokens"
        );
        require(
            token.allowance(msg.sender, address(this)) ==
                games[_gameId].betAmount,
            "Not enough allowance"
        );

        bool success = token.transferFrom(
            msg.sender,
            address(this),
            games[_gameId].betAmount
        );

        if (success) {
            games[_gameId].totalAmount += games[_gameId].betAmount;
            games[_gameId].playerGameData[playerIndex].playerState = PlayerState
                .Betted;

            if (
                games[_gameId].playerGameData[0].playerState ==
                PlayerState.Betted &&
                games[_gameId].playerGameData[1].playerState ==
                PlayerState.Betted
            ) {
                games[_gameId].state = GameState.WaitingForPlayersToSubmitMove;

                emit GameStarted(
                    _gameId,
                    games[_gameId].playerA,
                    games[_gameId].playerB
                );
            } else {
                games[_gameId].state = GameState.WaitingForPlayersToBet;
            }
        }

        return success;
    }

    function submitMove(uint256 _gameId, bytes32 _moveHash)
        external
        isValidGame(_gameId)
        isValidGamePlayer(_gameId, msg.sender)
    {
        require(
            games[_gameId].state == GameState.WaitingForPlayersToSubmitMove,
            "Betting not done"
        );
        require(
            games[_gameId].playerGameData[0].playerState ==
                PlayerState.SubmittedMove,
            "Move already submitted"
        );
        require(_moveHash != bytes32(0), "MoveHash null");

        uint8 playerIndex = msg.sender == owner ? 0 : 1;

        games[_gameId].playerGameData[playerIndex].move = _moveHash;
        games[_gameId].playerGameData[playerIndex].playerState = PlayerState
            .SubmittedMove;

        if (
            games[_gameId].playerGameData[0].playerState ==
            PlayerState.SubmittedMove &&
            games[_gameId].playerGameData[1].playerState ==
            PlayerState.SubmittedMove
        ) {
            games[_gameId].state = GameState.WaitingForPlayersToReveal;
        }

        emit MoveSubmitted(msg.sender, _gameId, _moveHash);
    }

    function revealMove(
        uint256 _gameId,
        uint8 _move,
        bytes32 _salt
    ) external isValidGame(_gameId) isValidGamePlayer(_gameId, msg.sender) {
        require(
            games[_gameId].state == GameState.WaitingForPlayersToReveal,
            "Move submissions not done"
        );

        uint8 playerIndex = msg.sender == owner ? 0 : 1;

        require(
            games[_gameId].playerGameData[playerIndex].playerState ==
                PlayerState.Revealed,
            "Player already revealed"
        );

        bytes32 _moveHash = keccak256(abi.encodePacked(_move, _salt));
        require(
            _moveHash == games[_gameId].playerGameData[playerIndex].move,
            "MoveHash invalid"
        );

        if (_move > 3) {
            games[_gameId].playerGameData[playerIndex].move = bytes32(0);
            games[_gameId].playerGameData[playerIndex].playerState = PlayerState
                .Initialized;
        }

        games[_gameId].playerGameData[playerIndex].move = keccak256(
            abi.encodePacked(_move)
        );

        emit MoveRevealed(msg.sender, _gameId, _move);

        if (
            games[_gameId].playerGameData[0].playerState ==
            PlayerState.Revealed &&
            games[_gameId].playerGameData[1].playerState == PlayerState.Revealed
        ) {
            getGameResult(_gameId);
        }
    }

    function getGameResult(uint256 _gameId) private {
        bytes32 playerAMove = games[_gameId].playerGameData[0].move;
        bytes32 playerBMove = games[_gameId].playerGameData[1].move;

        if (playerAMove == playerBMove) {
            games[_gameId].winner = address(0);
        } else if (playerAMove == ROCK) {
            games[_gameId].winner = games[_gameId].playerGameData[1].move ==
                PAPER
                ? games[_gameId].playerB
                : games[_gameId].playerA;
        } else if (playerAMove == PAPER) {
            games[_gameId].winner = games[_gameId].playerGameData[1].move ==
                SCISSORS
                ? games[_gameId].playerB
                : games[_gameId].playerA;
        } else {
            games[_gameId].winner = games[_gameId].playerGameData[1].move ==
                ROCK
                ? games[_gameId].playerB
                : games[_gameId].playerA;
        }

        games[_gameId].state = GameState.Finished;

        emit GameFinished(
            _gameId,
            games[_gameId].playerA,
            games[_gameId].playerB,
            games[_gameId].winner
        );
    }

    function requestRematch(uint256 _gameId)
        external
        isValidGame(_gameId)
        isValidGamePlayer(_gameId, msg.sender)
    {
        require(
            games[_gameId].state == GameState.Finished,
            "Game not finished"
        );

        uint8 playerIndex = msg.sender == owner ? 0 : 1;

        games[_gameId].playerGameData[playerIndex].playerState = PlayerState
            .Rematch;

        if (
            games[_gameId].playerGameData[0].playerState ==
            PlayerState.Rematch &&
            games[_gameId].playerGameData[1].playerState == PlayerState.Rematch
        ) {
            games[_gameId].state = GameState.WaitingForPlayersToBet;
        }
    }

    // Public getters

    function getGameId(address _player) public view returns (uint256) {
        return gamesMapping[_player];
    }

    function getGameBetAmount(uint256 _gameId) public view returns (uint256) {
        return games[_gameId].betAmount;
    }

    function getGamePlayers(uint256 _gameId)
        public
        view
        returns (address, address)
    {
        return (games[_gameId].playerA, games[_gameId].playerB);
    }

    function getGame(uint256 _gameId)
        public
        view
        returns (
            address,
            address,
            address,
            uint256
        )
    {
        return (
            games[_gameId].playerA,
            games[_gameId].playerB,
            games[_gameId].winner,
            games[_gameId].betAmount
        );
    }
}
