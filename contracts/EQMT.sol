// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

contract EQMT {

    address public admin;

    struct Position {
        uint16 fcid;
        uint64 bid;
        string sanity;
        uint256 baseequity;
        uint256 equityBalance;
        bool active;
        address owner;
    }

    // UUID → Position
    mapping(bytes32 => Position) public positions;

    // Wallet → active UUID
    mapping(address => bytes32) public activeUUID;

    // ------------------------ EVENTS ------------------------

    event EQMTMinted(
        bytes32 indexed uuid,
        address owner,
        uint16 fcid,
        uint64 bid,
        string sanity,
        uint256 baseequity
    );

    event EQMTCredited(
        bytes32 indexed uuid,
        uint256 amount,
        string ref
    );

    event EQMTLiquidated(
        bytes32 indexed uuid,
        uint256 amount,
        address to
    );

    event EQMTOwnerChanged(
        bytes32 indexed uuid,
        address from,
        address to
    );

    event EQMTClosed(bytes32 indexed uuid);
    event EQMTBurned(bytes32 indexed uuid);

    // ------------------------ MODIFIERS ------------------------

    modifier onlyAdmin() {
        require(msg.sender == admin, "Admin only");
        _;
    }

    modifier positionExists(bytes32 uuid) {
        require(positions[uuid].owner != address(0), "Position does not exist");
        _;
    }

    constructor() {
        admin = msg.sender;
    }

    // ------------------------ ADMIN FUNCTIONS ------------------------

    // Mint or overwrite a position
    function mintEQMT(
        bytes32 uuid,
        address wallet,
        uint16 fcid,
        uint64 bid,
        string calldata sanity,
        uint256 baseequity
    )
        external
        onlyAdmin
    {
        // Close existing active UUID for this wallet
        bytes32 oldUUID = activeUUID[wallet];
        if (oldUUID != bytes32(0) && positions[oldUUID].active) {
            positions[oldUUID].active = false;
            emit EQMTClosed(oldUUID);
        }

        // Create/overwrite position
        positions[uuid] = Position({
            fcid: fcid,
            bid: bid,
            sanity: sanity,
            baseequity: baseequity,
            equityBalance: 0,
            active: true,
            owner: wallet
        });

        activeUUID[wallet] = uuid;

        emit EQMTMinted(uuid, wallet, fcid, bid, sanity, baseequity);
    }

    // Admin credits ETH into a position
    function creditEQMT(bytes32 uuid, string calldata ref)
        external
        payable
        onlyAdmin
        positionExists(uuid)
    {
        require(positions[uuid].active, "Position closed");
        require(msg.value > 0, "No ETH sent");

        positions[uuid].equityBalance += msg.value;

        emit EQMTCredited(uuid, msg.value, ref);
    }

    // Admin reassigns the position to a new wallet
    function adminReassign(bytes32 uuid, address newWallet)
        external
        onlyAdmin
        positionExists(uuid)
    {
        Position storage p = positions[uuid];
        address oldWallet = p.owner;

        // Close new wallet's existing active position, if any
        bytes32 existing = activeUUID[newWallet];
        if (existing != bytes32(0) && positions[existing].active) {
            positions[existing].active = false;
            emit EQMTClosed(existing);
        }

        p.owner = newWallet;
        activeUUID[newWallet] = uuid;

        emit EQMTOwnerChanged(uuid, oldWallet, newWallet);
    }

    // Close (but keep stored)
    function closeEQMT(bytes32 uuid)
        external
        onlyAdmin
        positionExists(uuid)
    {
        positions[uuid].active = false;
        emit EQMTClosed(uuid);
    }

    // Delete permanently
    function burnEQMT(bytes32 uuid)
        external
        onlyAdmin
        positionExists(uuid)
    {
        delete positions[uuid];
        emit EQMTBurned(uuid);
    }

    // ------------------------ CLIENT FUNCTIONS ------------------------

    // User withdraws full balance
    function liquidateEQMT(bytes32 uuid)
        external
        positionExists(uuid)
    {
        Position storage p = positions[uuid];

        require(p.owner == msg.sender, "Not owner");
        require(p.active, "Position closed");
        require(p.equityBalance > 0, "No balance");

        uint256 amount = p.equityBalance;
        p.equityBalance = 0;

        (bool sent, ) = msg.sender.call{value: amount}("");
        require(sent, "Transfer failed");

        emit EQMTLiquidated(uuid, amount, msg.sender);
    }

    // ------------------------ VIEW HELPERS ------------------------

    function getPosition(bytes32 uuid)
        external
        view
        returns (Position memory)
    {
        return positions[uuid];
    }

    function getActiveUUID(address wallet)
        external
        view
        returns (bytes32)
    {
        return activeUUID[wallet];
    }
}
