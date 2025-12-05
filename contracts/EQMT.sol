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
    mapping(string => Position) public positions;

    // Wallet → currently active UUID (empty or old UUID if closed)
    mapping(address => string) public activeUUID;

    // ------------------------ EVENTS ------------------------

    event EQMTMinted(string uuid, address owner, uint16 fcid, uint64 bid, string sanity, uint256 baseequity);
    event EQMTCredited(string uuid, uint256 amount, string reference);
    event EQMTLiquidated(string uuid, uint256 amount, address to);
    event EQMTOwnerChanged(string uuid, address from, address to);
    event EQMTClosed(string uuid);
    event EQMTBurned(string uuid);

    // ------------------------ MODIFIERS ------------------------

    modifier onlyAdmin() {
        require(msg.sender == admin, "Admin only");
        _;
    }

    modifier positionExists(string memory uuid) {
        require(positions[uuid].owner != address(0), "Position does not exist");
        _;
    }

    constructor() {
        admin = msg.sender;
    }

    // ------------------------ ADMIN FUNCTIONS ------------------------

    // Mint new position OR overwrite existing UUID
    // One active position per wallet is enforced
    function mintEQMT(
        string calldata uuid,
        address wallet,
        uint16 fcid,
        uint64 bid,
        string calldata sanity,
        uint256 baseequity
    )
        external
        onlyAdmin
    {
        // Close old active position for this wallet if needed
        string memory oldUUID = activeUUID[wallet];
        if (bytes(oldUUID).length > 0 && positions[oldUUID].active == true) {
            positions[oldUUID].active = false;
            emit EQMTClosed(oldUUID);
        }

        // Overwrite or create the new position
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


    // Admin credits ETH to a UUID, must attach msg.value
    function creditEQMT(string calldata uuid, string calldata reference)
        external
        payable
        onlyAdmin
        positionExists(uuid)
    {
        require(positions[uuid].active, "Position closed");
        require(msg.value > 0, "No ETH sent");

        positions[uuid].equityBalance += msg.value;

        emit EQMTCredited(uuid, msg.value, reference);
    }


    // Admin can move position to another wallet
    function adminReassign(string calldata uuid, address newWallet)
        external
        onlyAdmin
        positionExists(uuid)
    {
        address oldWallet = positions[uuid].owner;

        // Mark previous UUID of newWallet as closed if active
        string memory oldUUID = activeUUID[newWallet];
        if (bytes(oldUUID).length > 0 && positions[oldUUID].active == true) {
            positions[oldUUID].active = false;
            emit EQMTClosed(oldUUID);
        }

        positions[uuid].owner = newWallet;
        activeUUID[newWallet] = uuid;

        emit EQMTOwnerChanged(uuid, oldWallet, newWallet);
    }


    // Close a position (keeps historical data)
    function closeEQMT(string calldata uuid)
        external
        onlyAdmin
        positionExists(uuid)
    {
        positions[uuid].active = false;
        emit EQMTClosed(uuid);
    }


    // Delete position forever
    function burnEQMT(string calldata uuid)
        external
        onlyAdmin
        positionExists(uuid)
    {
        delete positions[uuid];
        emit EQMTBurned(uuid);
    }


    // ------------------------ CLIENT FUNCTION ------------------------

    // Client withdraws full balance
    function liquidateEQMT(string calldata uuid)
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

    function getPosition(string calldata uuid)
        external
        view
        returns (Position memory)
    {
        return positions[uuid];
    }

    function getActiveUUID(address wallet)
        external
        view
        returns (string memory)
    {
        return activeUUID[wallet];
    }
}
