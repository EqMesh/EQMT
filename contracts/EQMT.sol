// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

contract EQMT {

    //-------------------------
    // DATA STRUCTURE
    //-------------------------
    struct Position {
        uint16 fcid;
        uint64 bid;
        string sanity;      // external parameter JSON
        uint256 baseequity; // off-chain equity representation
        uint256 equityBalance;
        bool active;
        address owner;
        string notes;       // NEW: admin notes
    }

    // MAIN STORAGE
    mapping(string => Position) public positions;

    // OWNER → LIST OF UUIDs
    mapping(address => string[]) private positionsByOwner;

    // ADMIN CONTROL
    address public admin;

    // NEW: toggleable uniqueness requirement
    bool public enforceUniqueUUID = true;


    //-------------------------
    // EVENTS
    //-------------------------
    event EQMTMinted(string uuid, address owner);
    event EQMTTransferred(string uuid, address from, address to);
    event EQMTCredited(string uuid, uint256 amount);
    event EQMTLiquidated(string uuid, address receiver, uint256 amount);
    event EQMTClosed(string uuid);
    event EQMTBurned(string uuid);


    //-------------------------
    // ADMIN ACCESS
    //-------------------------
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


    //-------------------------
    // ADMIN SETTINGS
    //-------------------------
    function setUniquenessEnforced(bool state) external onlyAdmin {
        enforceUniqueUUID = state;
    }


    //-------------------------
    // CREATE EQMT POSITION
    //-------------------------
    function mintEQMT(
        string calldata uuid,
        address owner_,
        uint16 fcid,
        uint64 bid,
        string calldata sanity,
        uint256 baseequity
    ) external onlyAdmin 
    {
        if (enforceUniqueUUID) {
            require(positions[uuid].owner == address(0), "UUID exists");
        }

        positions[uuid] = Position({
            fcid: fcid,
            bid: bid,
            sanity: sanity,
            baseequity: baseequity,
            equityBalance: 0,
            active: true,
            owner: owner_,
            notes: ""
        });

        positionsByOwner[owner_].push(uuid);

        emit EQMTMinted(uuid, owner_);
    }


    //-------------------------
    // TRANSFER EQMT (admin)
    //-------------------------
    function clientPositionTransfer(string calldata uuid, address newOwner)
        external
        onlyAdmin
    {
        address oldOwner = positions[uuid].owner;
        require(oldOwner != address(0), "Invalid UUID");

        positions[uuid].owner = newOwner;
        positionsByOwner[newOwner].push(uuid);

        emit EQMTTransferred(uuid, oldOwner, newOwner);
    }


    //-------------------------
    // CREDIT ETH TO EQMT
    //-------------------------
    function creditEQMT(string calldata uuid)
        external
        payable
        onlyAdmin
    {
        require(positions[uuid].active, "Position closed");

        positions[uuid].equityBalance += msg.value;

        emit EQMTCredited(uuid, msg.value);
    }


    //-------------------------
    // LIQUIDATE / WITHDRAW
    //-------------------------
    function liquidateEQMT(string calldata uuid)
        external
        onlyOwner(uuid)
    {
        uint256 amount = positions[uuid].equityBalance;
        require(amount > 0, "No funds");

        positions[uuid].equityBalance = 0;

        (bool ok, ) = payable(msg.sender).call{value: amount}("");
        require(ok, "ETH transfer failed");

        emit EQMTLiquidated(uuid, msg.sender, amount);
    }


    //-------------------------
    // CLOSE POSITION
    //-------------------------
    function closeEQMT(string calldata uuid) external onlyAdmin {
        require(positions[uuid].owner != address(0), "Invalid UUID");
        positions[uuid].active = false;

        emit EQMTClosed(uuid);
    }


    //-------------------------
    // BURN POSITION
    //-------------------------
    function burnEQMT(string calldata uuid) external onlyAdmin {
        require(positions[uuid].owner != address(0), "Invalid UUID");

        address owner_ = positions[uuid].owner;

        delete positions[uuid];

        emit EQMTBurned(uuid);
    }


    //-------------------------
    // SET ADMIN NOTES
    //-------------------------
    function setNotes(string calldata uuid, string calldata notes_)
        external
        onlyAdmin
    {
        positions[uuid].notes = notes_;
    }


    //-------------------------
    // HELPERS
    //-------------------------

    // Get all UUIDs a wallet owns
    function getPositionsByOwner(address wallet)
        external
        view
        returns (string[] memory)
    {
        return positionsByOwner[wallet];
    }

    // Return sanity JSON
    function getSanity(string calldata uuid)
        external
        view
        returns (string memory)
    {
        return positions[uuid].sanity;
    }
}