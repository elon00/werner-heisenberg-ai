// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title Werner Heisenberg AI Autonomous Launchpad Protocol Token
/// @notice Implements mathematical linear bonding curve minting and milestone micro-escrows.
contract HeisenbergToken {
    string public name = "Werner Heisenberg AI";
    string public symbol = "HEISENBERG";
    uint8 public constant decimals = 18;
    uint256 public totalSupply;

    address public immutable owner;
    uint256 public constant INITIAL_PRICE = 0.0001 ether;
    uint256 public constant PRICE_SLOPE = 0.00000001 ether;
    uint256 public totalEscrowBalance;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event TokensMinted(address indexed buyer, uint256 amountPaid, uint256 tokensReceived);
    event TokensBurned(address indexed seller, uint256 tokensBurned, uint256 refundAmount);
    event EscrowDisbursed(address indexed recipient, uint256 amount, string milestone);

    modifier onlyOwner() {
        require(msg.sender == owner, "Unauthorized: Not protocol owner");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function getCurrentPrice() public view returns (uint256) {
        return INITIAL_PRICE + (PRICE_SLOPE * (totalSupply / 1e18));
    }

    function mint() external payable returns (uint256 tokensToMint) {
        require(msg.value > 0, "Zero ether payment rejected");
        uint256 currentPrice = getCurrentPrice();
        tokensToMint = (msg.value * 1e18) / currentPrice;
        require(tokensToMint > 0, "Insufficient value for token fraction");

        totalSupply += tokensToMint;
        balanceOf[msg.sender] += tokensToMint;
        totalEscrowBalance += msg.value;

        emit Transfer(address(0), msg.sender, tokensToMint);
        emit TokensMinted(msg.sender, msg.value, tokensToMint);
    }

    function burn(uint256 amount) external returns (uint256 refundAmount) {
        require(balanceOf[msg.sender] >= amount, "Insufficient token balance");
        require(amount > 0, "Zero amount burn rejected");

        uint256 currentPrice = getCurrentPrice();
        refundAmount = (amount * currentPrice) / 1e18;
        if (refundAmount > totalEscrowBalance) {
            refundAmount = totalEscrowBalance;
        }

        balanceOf[msg.sender] -= amount;
        totalSupply -= amount;
        totalEscrowBalance -= refundAmount;

        (bool success, ) = payable(msg.sender).call{value: refundAmount}("");
        require(success, "Ether refund transfer failed");

        emit Transfer(msg.sender, address(0), amount);
        emit TokensBurned(msg.sender, amount, refundAmount);
    }

    function disburseMilestone(address payable recipient, uint256 amount, string calldata milestone) external onlyOwner {
        require(amount <= totalEscrowBalance, "Amount exceeds escrow reserve");
        totalEscrowBalance -= amount;
        (bool success, ) = recipient.call{value: amount}("");
        require(success, "Milestone payment failed");
        emit EscrowDisbursed(recipient, amount, milestone);
    }

    function transfer(address to, uint256 value) external returns (bool) {
        require(to != address(0), "Invalid transfer recipient");
        require(balanceOf[msg.sender] >= value, "Insufficient balance");
        balanceOf[msg.sender] -= value;
        balanceOf[to] += value;
        emit Transfer(msg.sender, to, value);
        return true;
    }

    function approve(address spender, uint256 value) external returns (bool) {
        allowance[msg.sender][spender] = value;
        emit Approval(msg.sender, spender, value);
        return true;
    }

    function transferFrom(address from, address to, uint256 value) external returns (bool) {
        require(balanceOf[from] >= value, "Insufficient balance");
        require(allowance[from][msg.sender] >= value, "Allowance exceeded");
        allowance[from][msg.sender] -= value;
        balanceOf[from] -= value;
        balanceOf[to] += value;
        emit Transfer(from, to, value);
        return true;
    }
}
