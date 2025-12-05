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

    // Primary position storage
    mapping(string => Position) public positions;

    // UUID index for search & prefix filtering
    string[] private uuidIndex;

    // Admin address
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
    event EQMTCredited(string uuid, uint256 amountWei);
    event EQMTLiquidated(string uuid, address owner, uint256 amountWei);
    event EQMTClosed(string uuid);
    event EQMTBurned(string uuid);

    // ------------------------------------------------------------
    // INTERNAL: PREFIX MATCH
    // ------------------------------------------------------------
    function _startsWith(string memory full, string memory prefix)
        internal
        pure
        returns (bool)
    {
        bytes memory f = bytes(full);
        bytes memory p = bytes(prefix);

        if (p.length > f.length) return false;

        for (uint256 i = 0; i < p.length; i++) {
            if (f[i] != p[i]) return false;
        }
        return true;
    }

    // ------------------------------------------------------------
    // PUBLIC VIEW: PREFIX SEARCH
    // ------------------------------------------------------------
    function findPositionsByUUIDPrefix(string calldata prefix)
        external
        view
        returns (string[] memory)
    {
        uint256 total = uuidIndex.length;
        uint256 count = 0;

        // First pass: count matches
        for (uint256 i = 0; i < total; i++) {
            if (_startsWith(uuidIndex[i], prefix)) {
                // Only return real, non-burned positions
                if (positions[uuidIndex[i]].owner != address(0)) {
                    count++;
                }
            }
        }

        // Second pass: populate result
        string[] memory result = new string[](count);
        uint256 index = 0;

        for (uint256 i = 0; i < total; i++) {
            if (_startsWith(uuidIndex[i], prefix)) {
                if (positions[uuidIndex[i]].owner != address(0)) {
                    result[index] = uuidIndex[i];
                    index++;
                }
            }
        }

        return result;
    }

    // ------------------------------------------------------------
    // MINT POSITION
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

        uuidIndex.push(uuid);

        emit EQMTMinted(uuid, owner_, fcid, bid);
    }

    // ------------------------------------------------------------
    // ADMIN-ONLY POSITION TRANSFER
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
    // CREDIT POSITION (REAL ETH USING msg.value ONLY)
    // ------------------------------------------------------------
    function creditEQMT(string calldata uuid)
        external
        payable
        onlyAdmin
        positionExists(uuid)
    {
        require(positions[uuid].active, "Position closed");

        positions[uuid].equityBalance += msg.value;

        emit EQMTCredited(uuid, msg.value);
    }

    // ------------------------------------------------------------
    // CLIENT LIQUIDATION (WITHDRAW ETH)
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
    // CLOSE POSITION
    // ------------------------------------------------------------
    function closeEQMT(string calldata uuid)
        external
        onlyAdmin
        positionExists(uuid)
    {
        positions[uuid].active = false;
        emit EQMTClosed(uuid);
    }

    // ------------------------------------------------------------
    // BURN POSITION (DELETES FROM STORAGE)
    // ------------------------------------------------------------
    function burnEQMT(string calldata uuid)
        external
        onlyAdmin
        positionExists(uuid)
    {
        delete positions[uuid];
        emit EQMTBurned(uuid);
    }
}
