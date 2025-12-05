// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

contract EQMT {

    struct Position {
        uint16 fcid;
        uint64 bid;
        string sanity;
        uint256 baseequity;
        uint256 equityBalance;
        bool active;
        address owner;
    }

    mapping(string => Position) public positions;

    address public admin;

    constructor() {
        admin = msg.sender;
    }

    modifier onlyAdmin() {
        require(msg.sender == admin, "Admin only");
        _;
    }

    modifier onlyOwner(string memory uuid) {
        require(msg.sender == positions[uuid].owner, "Not position owner");
        _;
    }

    modifier positionExists(string memory uuid) {
        require(positions[uuid].owner != address(0), "Position does not exist");
        _;
    }

    // EVENTS
    event EQMTMinted(string uuid, address owner, uint16 fcid, uint64 bid);
    event EQMTTransferred(string uuid, address oldOwner, address newOwner);
    event EQMTCredited(string uuid, uint256 amountWei);
    event EQMTLiquidated(string uuid, address owner, uint256 amountWei);
    event EQMTClosed(string uuid);
    event EQMTBurned(string uuid);

    // ------------------------------------------------------------
    // DECIMAL STRING PARSER (supports up to 18 decimals)
    // ------------------------------------------------------------
    function parseEthString(string memory ethStr) public pure returns (uint256) {
        bytes memory s = bytes(ethStr);
        require(s.length > 0, "Empty amount");

        uint256 integerPart = 0;
        uint256 fractionalPart = 0;
        uint256 fractionalLength = 0;

        bool hasDecimal = false;

        for (uint256 i = 0; i < s.length; i++) {
            bytes1 c = s[i];

            if (c == ".") {
                require(!hasDecimal, "Multiple decimals");
                hasDecimal = true;
                continue;
            }

            require(c >= "0" && c <= "9", "Invalid character");

            uint8 digit = uint8(c) - 48;

            if (!hasDecimal) {
                integerPart = integerPart * 10 + digit;
            } else {
                // Only up to 18 decimals allowed
                require(fractionalLength < 18, "Too many decimals");
                fractionalPart = fractionalPart * 10 + digit;
                fractionalLength++;
            }
        }

        // Scale fractional part to wei
        if (fractionalLength < 18) {
            fractionalPart *= 10 ** (18 - fractionalLength);
        }

        uint256 totalWei = integerPart * 1e18 + fractionalPart;
        return totalWei;
    }

    // ------------------------------------------------------------
    // CREATE POSITION
    // ------------------------------------------------------------
    function mintEQMT(
        string calldata uuid,
        address owner_,
        uint16 fcid,
        uint64 bid,
        string calldata sanity,
        uint256 baseequity
    ) external onlyAdmin 
    {
        require(positions[uuid].owner == address(0), "UUID exists");

        positions[uuid] = Position({
            fcid: fcid,
            bid: bid,
            sanity: sanity,
            baseequity: baseequity,
            equityBalance: 0,
            active: true,
            owner: owner_
        });

        emit EQMTMinted(uuid, owner_, fcid, bid);
    }

    // ------------------------------------------------------------
    // ADMIN TRANSFER POSITION
    // ------------------------------------------------------------
    function clientPositionTransfer(string calldata uuid, address newOwner)
        external
        onlyAdmin
        positionExists(uuid)
    {
        address oldOwner = positions[uuid].owner;
        positions[uuid].owner = newOwner;

        emit EQMTTransferred(uuid, oldOwner, newOwner);
    }

    // ------------------------------------------------------------
    // CREDIT POSITION WITH REAL ETH (string amount)
    // ------------------------------------------------------------
    function creditEQMT(string calldata uuid, string calldata amountEthString)
        external
        payable
        onlyAdmin
        positionExists(uuid)
    {
        require(positions[uuid].active, "Position closed");

        uint256 parsedWei = parseEthString(amountEthString);

        require(msg.value == parsedWei, "Amount mismatch");

        positions[uuid].equityBalance += parsedWei;

        emit EQMTCredited(uuid, parsedWei);
    }

    // ------------------------------------------------------------
    // LIQUIDATE POSITION (OWNER WITHDRAWS ETH)
    // ------------------------------------------------------------
    function liquidateEQMT(string calldata uuid)
        external
        positionExists(uuid)
        onlyOwner(uuid)
    {
        uint256 amount = positions[uuid].equityBalance;
        require(amount > 0, "No funds");

        positions[uuid].equityBalance = 0;

        (bool ok, ) = payable(msg.sender).call{value: amount}("");
        require(ok, "ETH transfer failed");

        emit EQMTLiquidated(uuid, msg.sender, amount);
    }

    // ------------------------------------------------------------
    // ADMIN ACTIONS
    // ------------------------------------------------------------
    function closeEQMT(string calldata uuid)
        external
        onlyAdmin
        positionExists(uuid)
    {
        positions[uuid].active = false;
        emit EQMTClosed(uuid);
    }

    function burnEQMT(string calldata uuid)
        external
        onlyAdmin
        positionExists(uuid)
    {
        delete positions[uuid];
        emit EQMTBurned(uuid);
    }
}
