// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

/*
 * EqMesh EQMT Position Registry
 * ----------------------------------
 * Transparent ledger for:
 *  - UUID-based client positions
 *  - Off-chain references (fcid, bid, sanity, base equity)
 *  - Real ETH crediting for proof of transaction
 *  - Client-controlled liquidation (withdrawal)
 *  - Admin-controlled management
 *
 * Not ERC-20 or ERC-721.
 * Pure position registry.
 */

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

    // ------------------------------------------------------------
    // EVENTS
    // ------------------------------------------------------------

    event EQMTMinted(string uuid, address owner, uint16 fcid, uint64 bid);
    event EQMTTransferred(string uuid, address oldOwner, address newOwner);
    event EQMTCredited(string uuid, uint256 amount);
    event EQMTLiquidated(string uuid, address owner, uint256 amount);
    event EQMTClosed(string uuid);
    event EQMTBurned(string uuid);

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
    // ADMIN-ONLY POSITION TRANSFER
    // (Renamed from adminReassign)
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
    // CREDIT POSITION WITH REAL ETH
    // (Renamed from creditProfit)
    // ------------------------------------------------------------
    function creditEQMT(string calldata uuid, uint256 amount)
        external
        payable
        onlyAdmin
        positionExists(uuid)
    {
        require(positions[uuid].active, "Position closed");
        require(msg.value == amount, "Amount mismatch");

        positions[uuid].equityBalance += amount;

        emit EQMTCredited(uuid, amount);
    }

    // ------------------------------------------------------------
    // CLIENT WITHDRAWAL OF REAL ETH
    // (Renamed from withdrawProfit)
    // ------------------------------------------------------------
    function liquidateEQMT(string calldata uuid)
        external
        positionExists(uuid)
        onlyOwner(uuid)
    {
        uint256 amount = positions[uuid].equityBalance;
        require(amount > 0, "No funds available");

        positions[uuid].equityBalance = 0;

        (bool ok, ) = payable(msg.sender).call{value: amount}("");
        require(ok, "ETH transfer failed");

        emit EQMTLiquidated(uuid, msg.sender, amount);
    }

    // ------------------------------------------------------------
    // POSITION ADMINISTRATION
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
