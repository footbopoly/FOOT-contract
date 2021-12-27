

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

library SafeMath {

    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");

        return c;
    }

    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        return sub(a, b, "SafeMath: subtraction overflow");
    }

    function sub(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b <= a, errorMessage);
        uint256 c = a - b;

        return c;
    }

}

interface ItokenRecipient {
    function receiveApproval(address _from, uint256 _value, address _token, bytes calldata _extraData) external returns (bool);
}

interface IERC20Token {
    function totalSupply() external view returns (uint256 supply);
    function transfer(address _to, uint256 _value) external  returns (bool success);
    function transferFrom(address _from, address _to, uint256 _value) external returns (bool success);
    function balanceOf(address _owner) external view returns (uint256 balance);
    function approve(address _spender, uint256 _value) external returns (bool success);
    function allowance(address _owner, address _spender) external view returns (uint256 remaining);
}

contract Ownable {

    address private owner;

    event OwnerSet(address indexed oldOwner, address indexed newOwner);

    modifier onlyOwner() {
        require(msg.sender == owner, "Caller is not owner");
        _;
    }

    constructor() {
        owner = msg.sender; // 'msg.sender' is sender of current call, contract deployer for a constructor
        emit OwnerSet(address(0), owner);
    }


    function changeOwner(address newOwner) public onlyOwner {
        emit OwnerSet(owner, newOwner);
        owner = newOwner;
    }

    function getOwner() external view returns (address) {
        return owner;
    }
}

contract StandardToken is IERC20Token {

    using SafeMath for uint256;
    mapping (address => uint256) public balances;
    mapping (address => mapping (address => uint256)) public allowed;
    uint256 public _totalSupply;

    event Transfer(address indexed _from, address indexed _to, uint256 _value);
    event Approval(address indexed _owner, address indexed _spender, uint256 _value);

    function totalSupply() override public view returns (uint256 supply) {
        return _totalSupply;
    }

    function transfer(address _to, uint256 _value) override virtual public returns (bool success) {
        require(_to != address(0x0), "Use burn function instead");
		require(_value >= 0, "Invalid amount");
		require(balances[msg.sender] >= _value, "Not enough balance");
		balances[msg.sender] = balances[msg.sender].sub(_value);
		balances[_to] = balances[_to].add(_value);
		emit Transfer(msg.sender, _to, _value);
        return true;
    }

    function transferFrom(address _from, address _to, uint256 _value) override virtual public returns (bool success) {
        require(_to != address(0x0), "Use burn function instead");
		require(_value >= 0, "Invalid amount");
		require(balances[_from] >= _value, "Not enough balance");
		require(allowed[_from][msg.sender] >= _value, "You need to increase allowance ");
		balances[_from] = balances[_from].sub(_value);
		balances[_to] = balances[_to].add(_value);
		emit Transfer(_from, _to, _value);
        return true;
    }

    function balanceOf(address _owner) override public view returns (uint256 balance) {
        return balances[_owner];
    }

    function approve(address _spender, uint256 _value) override public returns (bool success) {
        allowed[msg.sender][_spender] = _value;
        emit Approval(msg.sender, _spender, _value);
        return true;
    }

    function allowance(address _owner, address _spender) override public view returns (uint256 remaining) {
        return allowed[_owner][_spender];
    }

}

contract Foot is Ownable, StandardToken {

    using SafeMath for uint256;
    string public name = "Footbopoly";
    uint8 public decimals = 18;
    string public symbol = "FOOT";

  // Time lock for progressive release of team, marketing and platform balances
  struct TimeLock {
    uint256 totalAmount;
    uint256 lockedBalance;
    uint128 baseDate;
    uint64 step;
    uint64 tokensStep;
  }
  mapping (address => TimeLock) public timeLocks;

  // Prevent Bots - If true, limits transactions to 1 transfer per block (whitelisted can execute multiple transactions)
  bool public limitTransactions;
  mapping (address => bool) public contractsWhiteList;
  mapping (address => uint) public lastTXBlock;
  event Burn(address indexed from, uint256 value);

  // token sale

  // Wallet for the tokens to be sold, and receive ETH
  address payable public salesWallet;
  address payable public privateWallet;

  uint256 public soldOnPrivateSale;
  // TODO replace with actual numbers
  uint256 public PRIVATE_SALE_START = 1642204800;
  uint256 public PRIVATE_SALE_END = 1643587200;
  uint256 public constant PRIVATESALE_WEI_FACTOR = 200000;
  uint256 public constant PRIVATESALE_HARDCAP = 2500000 ether;

  uint256 public soldOnCrowdSale;
  // TODO replace with actual numbers
  uint256 public CROWD_SALE_START = 1643587200;
  uint256 public constant CROWD_SALE_END = 1644883200;
  uint256 public constant CROWDSALE_WEI_FACTOR = 100000;
  uint256 public constant CROWDSALE_HARDCAP = 7500000 ether;

  constructor() {
    _totalSupply = 310000000 ether;

    // Base date to calculate team, marketing and platform tokens lock
    uint256 lockStartDate =
//    1613494800;
      1622490778;

    // Team wallet - 12500000 tokens
    // 0 tokens free, 12500000 tokens locked - progressive release of 5% every 30 days (after 180 days of waiting period)
//    address team = 0xf1D3cE2B941CDb7b6F61394a41F04C24E738D3A5;
//    address team = 0x78D921F8D3410583A573D87A9257cb15efe11C01; // for tests
    address team = 0xc9329F122f8B6d086b1531bc074936367b3e647B; // for Ropsten
    balances[team] = 12500000 ether;
    timeLocks[team] = TimeLock(12500000 ether, 12500000 ether, uint128(lockStartDate + (180 days)), 30 days, 625000);
    emit Transfer(address(0x0), team, balances[team]);

    // Marketing wallet - 5000000 tokens
    // 1000000 tokens free, 4000000 tokens locked - progressive release of 5% every 30 days
//    address marketingWallet = 0xD38FbAaF200D32fd86173742bbEE8dD5f83D6715;
//    address marketingWallet = 0x28333236cfe9e4Da5010c22d601eA8E5cf6Ea19E; // for tests
    address marketingWallet = 0x9720CEE514484706BC944388422629ed388AeC43; // for Ropsten
    balances[marketingWallet] = 5000000 ether;
    timeLocks[marketingWallet] = TimeLock(4000000 ether, 4000000 ether, uint128(lockStartDate), 30 days, 200000);
    emit Transfer(address(0x0), marketingWallet, balances[marketingWallet]);

    // Game Evolution wallet - 7500000 tokens   - index 6 on ganache
    // 1000000 tokens free, 6500000 tokens locked - progressive release of 5% every 30 days
//    address gameEvolutionWallet = 0x3Ac2cffc9B7F3Bf0FEbB9674e2D3AE2495a717A2;
//    address gameEvolutionWallet = 0x5BD300D7c09DDA52719494607A8b06c405702A16; // for tests
    address gameEvolutionWallet = 0xcc8d076CA1A21e5Bff6946401f3ACa1ee5Bf17C7; // for Ropsten
    balances[gameEvolutionWallet] = 7500000 ether;
    timeLocks[gameEvolutionWallet] = TimeLock(6500000 ether, 6500000 ether, uint128(lockStartDate), 30 days, 325000);
    emit Transfer(address(0x0), gameEvolutionWallet, balances[gameEvolutionWallet]);

    // Private sale wallet - 2500000 tokens
//    privateWallet = payable(0x9C5f8788394cc01546782505159A6360d80e3fB5);
//    privateWallet = payable(0x80575E774B954a717c1E600723AC6945551afB43); // for tests
    privateWallet = payable(0x12Cfba593A423bda2ab8F3C9691691c66d8380d8); // for Ropsten
    balances[privateWallet] = 2500000 ether;
    emit Transfer(address(0x0), privateWallet, balances[privateWallet]);

    // Sales wallet, holds Pre-Sale balance - 7500000 tokens
//    salesWallet = payable(0x22beD7D43a368ca5519Afd66C4a666da00D9b333);
//    salesWallet = payable(0x5444d73Ad838712D8542f5b50d71D0834a7634cd); // for tests
    salesWallet = payable(0x6608c0c336BcDD38dEae1e998488E0C7fe017eae); // for Ropsten
    balances[salesWallet] = 7500000 ether;
    emit Transfer(address(0x0), salesWallet, balances[salesWallet]);

    // Exchanges - 25000000 tokens
//    address exchanges = 0x59682aa9effa9B8Cbd8c2A90df6a77271fB48fd1;
//    address exchanges = 0xFaDE135cdc959C9f4a7DD93f0e5BF1d4ffe432FB; //for tests
    address exchanges = 0x1EC6D9DEa414aF6775Ae060162e9338abdb0A187; //for Ropsten
    balances[exchanges] = 25000000 ether;
    emit Transfer(address(0x0), exchanges, balances[exchanges]);

    // Platform wallet - 200000000 tokens
    // 50000000 tokens free, 150000000 tokens locked - progressive release of 25000000 every 90 days
//    address platformWallet = 0x4106F3BFE6Fd8fFAd3e2d12601305fE6E87506a7;
//    address platformWallet = 0x520Ee868857A9D6E936525602313c301a559F84E; // for tests
    address platformWallet = 0x16D741FBBbbD1aBFB71F892AFc5d8C6682d1fbda; // for Ropsten
    balances[platformWallet] = 200000000 ether;
    timeLocks[platformWallet] = TimeLock(150000000 ether, 150000000 ether, uint128(lockStartDate), 90 days, 25000000);
    emit Transfer(address(0x0), platformWallet, balances[platformWallet]);
  }

  function setPublicSaleStartDate(uint256 newStartTimestamp) public onlyOwner {
      CROWD_SALE_START = newStartTimestamp;
  }

  function transfer(address _to, uint256 _value) override public returns (bool success) {
    require(checkTransferLimit(), "Transfers are limited to 1 per block");
    require(_value <= (balances[msg.sender] - timeLocks[msg.sender].lockedBalance));
    return super.transfer(_to, _value);
  }

  function transferFrom(address _from, address _to, uint256 _value) override public returns (bool success) {
    require(checkTransferLimit(), "Transfers are limited to 1 per block");
    require(_value <= (balances[_from] - timeLocks[_from].lockedBalance), "balance is locked");
    return super.transferFrom(_from, _to, _value);
  }

  function burn(uint256 _value) public returns (bool success) {
    require(balances[msg.sender] >= _value, "Not enough balance");
    require(_value >= 0, "Invalid amount");
    balances[msg.sender] = balances[msg.sender].sub(_value);
    _totalSupply = _totalSupply.sub(_value);
    emit Burn(msg.sender, _value);
    return true;
  }

  function approveAndCall(address _spender, uint256 _value, bytes memory _extraData) public returns (bool success) {
    allowed[msg.sender][_spender] = _value;
    emit Approval(msg.sender, _spender, _value);
    ItokenRecipient recipient = ItokenRecipient(_spender);
    require(recipient.receiveApproval(msg.sender, _value, address(this), _extraData));
    return true;
  }


  function releaseTokens(address _account) public {
    uint256 timeDiff = block.timestamp - uint256(timeLocks[_account].baseDate);
    require(timeDiff > uint256(timeLocks[_account].step), "Unlock point not reached yet");
    uint256 steps = (timeDiff / uint256(timeLocks[_account].step));
    uint256 unlockableAmount = ((uint256(timeLocks[_account].tokensStep) * 1 ether) * steps);
    if (unlockableAmount >=  timeLocks[_account].totalAmount) {
      timeLocks[_account].lockedBalance = 0;
    } else {
      timeLocks[_account].lockedBalance = timeLocks[_account].totalAmount - unlockableAmount;
    }
  }

  function checkTransferLimit() internal returns (bool txAllowed) {
    address _caller = msg.sender;
    if (limitTransactions == true && contractsWhiteList[_caller] != true) {
      if (lastTXBlock[_caller] == block.number) {
        return false;
      } else {
        lastTXBlock[_caller] = block.number;
        return true;
      }
    } else {
      return true;
    }
  }

  function enableTXLimit() public onlyOwner {
    limitTransactions = true;
  }

  function disableTXLimit() public onlyOwner {
    limitTransactions = false;
  }

  function includeWhiteList(address _contractAddress) public onlyOwner {
    contractsWhiteList[_contractAddress] = true;
  }

  function removeWhiteList(address _contractAddress) public onlyOwner {
    contractsWhiteList[_contractAddress] = false;
  }

  function getLockedBalance(address _wallet) public view returns (uint256 lockedBalance) {
    return timeLocks[_wallet].lockedBalance;
  }

  function buy() public payable {
    require((block.timestamp > CROWD_SALE_START) && (block.timestamp < CROWD_SALE_END), "Contract is not selling tokens");
    uint weiValue = msg.value;
    require(weiValue >= (5 * (10 ** 16)), "Minimum amount is 0.05 eth");
    require(weiValue <= (20 ether), "Maximum amount is 20 eth");
    uint amount = CROWDSALE_WEI_FACTOR * weiValue;
    require((soldOnCrowdSale) <= (CROWDSALE_HARDCAP), "That quantity is not available");
    soldOnCrowdSale += amount;
    balances[salesWallet] = balances[salesWallet].sub(amount);
    balances[msg.sender] = balances[msg.sender].add(amount);
    require(salesWallet.send(weiValue));
    emit Transfer(salesWallet, msg.sender, amount);
  }

  function burnUnsold() public onlyOwner {
    require(block.timestamp > CROWD_SALE_END);
    uint currentBalance = balances[salesWallet];
    balances[salesWallet] = 0;
    _totalSupply = _totalSupply.sub(currentBalance);
    emit Burn(salesWallet, currentBalance);
  }

  function buyPrivate() public payable {
    require((block.timestamp > PRIVATE_SALE_START) && (block.timestamp < PRIVATE_SALE_END), "Contract is not selling tokens");
    uint weiValue = msg.value;
    require(weiValue >= (5 * (10 ** 16)), "Minimum amount is 0.05 eth");
    require(weiValue <= (20 ether), "Maximum amount is 20 eth");
    uint amount = PRIVATESALE_WEI_FACTOR * weiValue;
    require((soldOnPrivateSale) <= (PRIVATESALE_HARDCAP), "That quantity is not available");
    soldOnPrivateSale += amount;
    if ((balances[privateWallet].sub(amount)) < ((5 * (10 ** 16)) * PRIVATESALE_WEI_FACTOR)) {
      amount = balances[privateWallet];
      CROWD_SALE_START = block.timestamp;
      PRIVATE_SALE_END = block.timestamp;
    }
    balances[privateWallet] = balances[privateWallet].sub(amount);
    balances[msg.sender] = balances[msg.sender].add(amount);
    require(privateWallet.send(weiValue));
    emit Transfer(privateWallet, msg.sender, amount);
  }

  function burnUnsoldPrivate() public onlyOwner {
    require(block.timestamp > PRIVATE_SALE_END);
    uint currentBalance = balances[privateWallet];
    balances[privateWallet] = 0;
    _totalSupply = _totalSupply.sub(currentBalance);
    emit Burn(privateWallet, currentBalance);
  }

  function saleDetails() public view returns (uint256 publicSaleStart, uint256 publicSaleEnd, uint256 privateSaleStart, uint256 privateSaleEnd, uint256 soldOnPublic, uint256 soldOnPrivate) {
    return (CROWD_SALE_START, CROWD_SALE_END, PRIVATE_SALE_START, PRIVATE_SALE_END, soldOnCrowdSale, soldOnPrivateSale);
  }

}
