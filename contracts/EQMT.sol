// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

contract EQMT {

    struct Position {
        uint16 fcid;
        uint64 bid;
        string sanity;
        uint256 baseequity;
        uint256 equityBalance;  // renamed from profitBalance
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

    // ------------------------------------------------------------
    // MINT — now accepts ANY string as UUID
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
        // Optional uniqueness: remove if not desired
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
    }

    // ------------------------------------------------------------
    // RENAME: adminReassign → clientPositionTransfer
    // ------------------------------------------------------------
    function clientPositionTransfer(string calldata uuid, address newOwner)
        external
        onlyAdmin
    {
        require(positions[uuid].owner != address(0), "Invalid UUID");
        positions[uuid].owner = newOwner;
    }

    // ------------------------------------------------------------
    // RENAME: creditProfit → creditEQMT
    // ------------------------------------------------------------
    function creditEQMT(string calldata uuid)
        external
        payable
        onlyAdmin
    {
        require(positions[uuid].active, "Position closed");
        positions[uuid].equityBalance += msg.value;
    }

    // ------------------------------------------------------------
    // RENAME: withdrawProfit → liquidateEQMT
    // ------------------------------------------------------------
    function liquidateEQMT(string calldata uuid)
        external
        onlyOwner(uuid)
    {
        uint256 amount = positions[uuid].equityBalance;
        require(amount > 0, "No funds");

        positions[uuid].equityBalance = 0;

        (bool ok, ) = payable(msg.sender).call{value: amount}("");
        require(ok, "ETH transfer failed");
    }

    // ------------------------------------------------------------
    // CLOSE / BURN
    // ------------------------------------------------------------
    function closeEQMT(string calldata uuid) external onlyAdmin {
        positions[uuid].active = false;
    }

    function burnEQMT(string calldata uuid) external onlyAdmin {
        delete positions[uuid];
    }
}
