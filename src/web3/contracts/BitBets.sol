pragma solidity ^0.4.24;
import "./IERC20.sol";

contract BitBets {
  mapping(uint => mapping(uint => uint)) public choiceBets;
  mapping(uint => mapping(address => uint)) public userBets;
  mapping(uint => mapping(address => bool)) public userWithdrawn;
  mapping(uint => mapping(address => bool)) public userRecovered;
  mapping(uint => address[]) takers;
  struct Bet {
    string terms;
    uint amount;
    string options;
    address oracle;
    uint outcome;
    uint totalPool;
    address paymentToken;
    bool invalid;
    uint betsPlaced;
  }

  Bet[] public bets;

  function createBet(string memory terms, uint amount, string memory options, address paymentToken) public {
    bets.push(Bet({
      terms: terms,
      amount: amount,
      options: options,
      oracle: msg.sender,
      outcome: 0,
      totalPool: 0,
      paymentToken: paymentToken,
      invalid: false,
      betsPlaced: 0
    }));
  }

  function placeBet(uint betIndex, uint option) public payable {
    Bet memory currentBet = bets[betIndex];
    if(currentBet.paymentToken == address(0)) {
      require(msg.value == currentBet.amount, "Must meet the bet requirement");
    } else {
      IERC20(currentBet.paymentToken).allowance(msg.sender, address(this)) >= currentBet.amount;
      IERC20(currentBet.paymentToken).transferFrom(msg.sender, address(this), currentBet.amount);
    }
    require(option > 0, "You must use 1 based indexes for choosing an option");
    require(currentBet.outcome == 0, "Cannot bet on a done game");
    require(!(currentBet.invalid), "Cannot bet on an invalid game");
    userBets[betIndex][msg.sender] = option;
    choiceBets[betIndex][option]++;
    takers[betIndex].push(msg.sender);
    bets[betIndex].totalPool += currentBet.amount;
    bets[betIndex].betsPlaced++;
  }

  function resolveBet(uint betIndex, uint outcome) public {
    Bet memory currentBet = bets[betIndex];
    require(currentBet.oracle == msg.sender, "You don't have permission to resolve this bet");
    require(outcome > 0, "Use 1 based indexes for outcome");
    require(!(currentBet.invalid), "Cannot resolve an invalid bet");
    bets[betIndex].outcome = outcome;
  }

  function invalidateBet(uint betIndex) public {
    Bet memory currentBet = bets[betIndex];
    require(currentBet.oracle == msg.sender, "You don't have permission to invalidate this bet");
    require(currentBet.outcome == 0, "Cannot invalidate a resolved bet");
    bets[betIndex].invalid = true;
  }

  function withdraw(uint betIndex) public {
    Bet memory currentBet = bets[betIndex];
    require(currentBet.outcome > 0, "Bet is not resolved");
    require(!(currentBet.invalid), "Cannot withdraw from an invalid bet");
    require(userBets[betIndex][msg.sender] == currentBet.outcome, "You didn't select the correct answer");
    require(userWithdrawn[betIndex][msg.sender] == false, "You've already withdrawn");
    userWithdrawn[betIndex][msg.sender] = true;
    uint reward = currentBet.totalPool / choiceBets[betIndex][currentBet.outcome];
    if(currentBet.paymentToken == address(0x0)) {
      address(msg.sender).transfer(reward);
    } else {
      IERC20(currentBet.paymentToken).transfer(msg.sender, reward);
    }
  }

  function recover(uint betIndex) public {
    Bet memory currentBet = bets[betIndex];
    require(currentBet.invalid, "Bet is not invalid");
    require(currentBet.outcome == 0, "Cannot recover from a resolved bet");
    require(userRecovered[betIndex][msg.sender] == false, "You've already recovered");
    userRecovered[betIndex][msg.sender] = true;
    uint reward = currentBet.totalPool / currentBet.betsPlaced;
    if(currentBet.paymentToken == address(0x0)) {
      address(msg.sender).transfer(reward);
    } else {
      IERC20(currentBet.paymentToken).transfer(msg.sender, reward);
    }
  }
}
