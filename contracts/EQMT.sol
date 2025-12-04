// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

contract EQMT {
    event EQMTCreated(bytes16 uuid, address owner, uint16 fcid, uint64 bid, uint256 baseequity);
    event EQMTProfitCredited(bytes16 uuid, uint256 amount);
    event EQMTProfitWithdrawn(bytes16 uuid, uint256 amount);
    event EQMTSanityUpdated(bytes16 uuid, string sanityJson);
    event EQMTReassigned(bytes16 uuid, address oldOwner, address newOwner);
    event EQMTClosed(bytes16 uuid);
    event EQMTBurned(bytes16 uuid);

    address public admin;

    modifier onlyAdmin() {
        require(msg.sender == admin, "Not admin");
        _;
    }

    modifier onlyOwnerOf(bytes16 uuid) {
        require(tokens[uuid].owner == msg.sender, "Not EQMT owner");
        _;
    }

    constructor() {
        admin = msg.sender;
    }

    struct EQMTData {
        bytes16 uuid;
        uint16 fcid;
        uint64 bid;
        string sanity;
        uint256 baseequity;

        address owner;
        uint256 profitBalance;
        bool active;
        bool exists;
    }

    mapping(bytes16 => EQMTData) public tokens;

    function mintEQMT(
        bytes16 uuid,
        address owner,
        uint16 fcid,
        uint64 bid,
    string memory sanityJson,
        uint256 baseequity
    ) external onlyAdmin {
        require(!tokens[uuid].exists, "UUID exists");

        tokens[uuid] = EQMTData({
            uuid: uuid,
            fcid: fcid,
            bid: bid,
            sanity: sanityJson,
            baseequity: baseequity,
            owner: owner,
            profitBalance: 0,
            active: true,
            exists: true
        });

        emit EQMTCreated(uuid, owner, fcid, bid, baseequity);
    }

    function creditProfit(bytes16 uuid) external payable onlyAdmin {
        require(tokens[uuid].exists, "Missing");
        require(tokens[uuid].active, "Inactive");
        require(msg.value > 0, "Zero ETH");

        tokens[uuid].profitBalance += msg.value;
        emit EQMTProfitCredited(uuid, msg.value);
    }

    function withdrawProfit(bytes16 uuid) external onlyOwnerOf(uuid) {
        uint256 amount = tokens[uuid].profitBalance;
        require(amount > 0, "Empty");

        tokens[uuid].profitBalance = 0;

        (bool ok, ) = msg.sender.call{value: amount}("");
        require(ok, "ETH transfer failed");

        emit EQMTProfitWithdrawn(uuid, amount);
    }

    function updateSanity(bytes16 uuid, string memory newSanityJson) external onlyAdmin {
        require(tokens[uuid].exists, "Missing");
        tokens[uuid].sanity = newSanityJson;
        emit EQMTSanityUpdated(uuid, newSanityJson);
    }

    function adminReassign(bytes16 uuid, address newOwner) external onlyAdmin {
        require(tokens[uuid].exists, "Missing");
        address old = tokens[uuid].owner;
        tokens[uuid].owner = newOwner;

        emit EQMTReassigned(uuid, old, newOwner);
    }

    function closeEQMT(bytes16 uuid) external onlyAdmin {
        require(tokens[uuid].exists, "Missing");
        tokens[uuid].active = false;
        emit EQMTClosed(uuid);
    }

    function burnEQMT(bytes16 uuid) external onlyAdmin {
        require(tokens[uuid].exists, "Missing");
        require(!tokens[uuid].active, "Must close first");

        delete tokens[uuid];
        emit EQMTBurned(uuid);
    }
}
