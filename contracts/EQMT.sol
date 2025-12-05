// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

contract EQMT {

    address public admin;

    struct Position {
        uint16 fcid;
        uint64 bid;
        string sanity;
        string uuid;            // plaintext UUID kept here
        uint256 baseequity;
        uint256 equityBalance;
        bool active;
        address owner;
    }

    // UUID (plaintext) → Position
    mapping(string => Position) public positions;

    // Wallet → currently active UUID (plaintext)
    mapping(address => string) public activeUUID;

    // ------------------------ EVENTS ------------------------
    // uuidHash = keccak256(bytes(uuid))
    // allows fast filtering on-chain
    event EQMTMinted(
        bytes32 indexed uuidHash,
        string uuid,
        address owner,
        uint16 fcid,
        uint64 bid,
        string sanity,
        uint256 baseequity
    );

    event EQMTCredited(
        bytes32 indexed uuidHash,
        string uuid,
        uint256 amount,
        string ref
    );

    event EQMTLiquidated(
        bytes32 indexed uuidHash,
        string uuid,
        uint256 amount,
        address to
    );

    event EQMTOwnerChanged(
        bytes32 indexed uuidHash,
        string uuid,
        address from,
        address to
    );

    event EQMTClosed(bytes32 indexed uuidHash, string uuid);
    event EQMTBurned(bytes32 indexed uuidHash, string uuid);

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
        // Close existing active position
        string memory oldUUID = activeUUID[wallet];
        if (bytes(oldUUID).length > 0 && positions[oldUUID].active) {
            positions[oldUUID].active = false;
            emit EQMTClosed(keccak256(bytes(oldUUID)), oldUUID);
        }

        positions[uuid] = Position({
            fcid: fcid,
            bid: bid,
            sanity: sanity,
            uuid: uuid,
            baseequity: baseequity,
            equityBalance: 0,
            active: true,
            owner: wallet
        });

        activeUUID[wallet] = uuid;

        emit EQMTMinted(
            keccak256(bytes(uuid)),
            uuid,
            wallet,
            fcid,
            bid,
            sanity,
            baseequity
        );
    }

    function creditEQMT(string calldata uuid, string calldata ref)
        external
        payable
        onlyAdmin
        positionExists(uuid)
    {
        require(positions[uuid].active, "Position closed");
        require(msg.value > 0, "No ETH sent");

        positions[uuid].equityBalance += msg.value;

        emit EQMTCredited(
            keccak256(bytes(uuid)),
            uuid,
            msg.value,
            ref
        );
    }

    function adminReassign(string calldata uuid, address newWallet)
        external
        onlyAdmin
        positionExists(uuid)
    {
        Position storage p = positions[uuid];
        address oldWallet = p.owner;

        string memory oldUUID = activeUUID[newWallet];
        if (bytes(oldUUID).length > 0 && positions[oldUUID].active) {
            positions[oldUUID].active = false;
            emit EQMTClosed(keccak256(bytes(oldUUID)), oldUUID);
        }

        p.owner = newWallet;
        activeUUID[newWallet] = uuid;

        emit EQMTOwnerChanged(
            keccak256(bytes(uuid)),
            uuid,
            oldWallet,
            newWallet
        );
    }

    function closeEQMT(string calldata uuid)
        external
        onlyAdmin
        positionExists(uuid)
    {
        positions[uuid].active = false;
        emit EQMTClosed(keccak256(bytes(uuid)), uuid);
    }

    function burnEQMT(string calldata uuid)
        external
        onlyAdmin
        positionExists(uuid)
    {
        delete positions[uuid];
        emit EQMTBurned(keccak256(bytes(uuid)), uuid);
    }

    // ------------------------ CLIENT FUNCTION ------------------------

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

        emit EQMTLiquidated(
            keccak256(bytes(uuid)),
            uuid,
            amount,
            msg.sender
        );
    }

    // ------------------------ VIEWS ------------------------

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
