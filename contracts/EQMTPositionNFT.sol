// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract EQMTPositionNFT is ERC721, Ownable {

    struct Position {
        uint16 fcid;
        uint64 bid;
        string sanity;
        uint256 baseequity;
        uint256 equityBalance;
        bool active;
    }

    mapping(uint256 => Position) public positions;
    mapping(uint256 => address) public positionOwner;

    constructor() ERC721("EqMesh Position Token", "EQMT") {}

    // ----------------------------------------------------------------------
    // SOULBOUND (NON-TRANSFERABLE BY USERS)
    // Using OZ v5 rules: override ONLY public transfer functions
    // ----------------------------------------------------------------------

    function approve(address, uint256) public pure override {
        revert("EQMT positions are non-transferable");
    }

    function setApprovalForAll(address, bool) public pure override {
        revert("EQMT positions are non-transferable");
    }

    function transferFrom(address, address, uint256) public pure override {
        revert("EQMT positions are non-transferable");
    }

    function safeTransferFrom(address, address, uint256) public pure override {
        revert("EQMT positions are non-transferable");
    }

    function safeTransferFrom(address, address, uint256, bytes memory) public pure override {
        revert("EQMT positions are non-transferable");
    }

    // ----------------------------------------------------------------------
    // CLIENT-FRIENDLY POSITION OPERATIONS
    // ----------------------------------------------------------------------

    function mintEQMT(
        uint256 uuid,
        address owner_,
        uint16 fcid,
        uint64 bid,
        string calldata sanity,
        uint256 baseequity
    ) external onlyOwner
    {
        require(_ownerOf(uuid) == address(0), "UUID already exists");

        // Mint NFT
        _safeMint(owner_, uuid);

        // Store metadata
        positions[uuid] = Position({
            fcid: fcid,
            bid: bid,
            sanity: sanity,
            baseequity: baseequity,
            equityBalance: 0,
            active: true
        });

        positionOwner[uuid] = owner_;
    }

    // Renamed from adminReassign — admin-controlled only
    function clientPositionTransfer(uint256 uuid, address newOwner) external onlyOwner {
        require(_ownerOf(uuid) != address(0), "Invalid UUID");

        positionOwner[uuid] = newOwner;

        // Admin transfer bypasses soulbound restrictions using internal update()
        _update(newOwner, uuid, address(0));
    }

    // Renamed from creditProfit — admin deposits ETH into position
    function creditEQMT(uint256 uuid) external payable onlyOwner {
        require(_ownerOf(uuid) != address(0), "Invalid UUID");
        require(positions[uuid].active, "Position closed");

        positions[uuid].equityBalance += msg.value;
    }

    // Renamed from withdrawProfit — user claims ETH
    function liquidateEQMT(uint256 uuid) external {
        require(_ownerOf(uuid) != address(0), "Invalid UUID");
        require(msg.sender == positionOwner[uuid], "Not position owner");

        uint256 amount = positions[uuid].equityBalance;
        require(amount > 0, "No funds available");

        positions[uuid].equityBalance = 0;

        (bool sent, ) = payable(msg.sender).call{value: amount}("");
        require(sent, "ETH transfer failed");
    }

    function closeEQMT(uint256 uuid) external onlyOwner {
        require(_ownerOf(uuid) != address(0), "Invalid UUID");
        positions[uuid].active = false;
    }

    function burnEQMT(uint256 uuid) external onlyOwner {
        require(_ownerOf(uuid) != address(0), "Invalid UUID");

        positions[uuid].active = false;
        delete positions[uuid];
        delete positionOwner[uuid];

        _burn(uuid);
    }
}
