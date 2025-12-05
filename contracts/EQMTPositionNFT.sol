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
    // NON-TRANSFERABLE OVERRIDES (soulbound behavior)
    // ----------------------------------------------------------------------
    function _transfer(address from, address to, uint256 tokenId) internal pure override {
        revert("EQMT positions are non-transferable");
    }

    function approve(address, uint256) public pure override {
        revert("EQMT positions are non-transferable");
    }

    function setApprovalForAll(address, bool) public pure override {
        revert("EQMT positions are non-transferable");
    }

    // ----------------------------------------------------------------------
    // CLIENT-FRIENDLY ACTION FUNCTIONS
    // ----------------------------------------------------------------------

    // Create a new EQMT position
    function mintEQMT(
        uint256 uuid,
        address owner_,
        uint16 fcid,
        uint64 bid,
        string calldata sanity,
        uint256 baseequity
    ) external onlyOwner 
    {
        require(!_exists(uuid), "UUID already exists");

        _safeMint(owner_, uuid);

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

    // Renamed from "adminReassign"
    function clientPositionTransfer(uint256 uuid, address newOwner) external onlyOwner {
        require(_exists(uuid), "Invalid UUID");
        positionOwner[uuid] = newOwner;

        // Move the NFT
        _safeTransfer(ownerOf(uuid), newOwner, uuid, "");
    }

    // Renamed from "creditProfit"
    function creditEQMT(uint256 uuid) external payable onlyOwner {
        require(_exists(uuid), "Invalid UUID");
        require(positions[uuid].active, "Position closed");
        positions[uuid].equityBalance += msg.value;
    }

    // Renamed from "withdrawProfit"
    function liquidateEQMT(uint256 uuid) external {
        require(_exists(uuid), "Invalid UUID");
        require(msg.sender == positionOwner[uuid], "Not position owner");

        uint256 amount = positions[uuid].equityBalance;
        require(amount > 0, "No funds available");

        positions[uuid].equityBalance = 0;

        (bool sent, ) = payable(msg.sender).call{value: amount}("");
        require(sent, "ETH transfer failed");
    }

    // Close and deactivate EQMT position
    function closeEQMT(uint256 uuid) external onlyOwner {
        require(_exists(uuid), "Invalid UUID");
        positions[uuid].active = false;
    }

    // Remove EQMT permanently
    function burnEQMT(uint256 uuid) external onlyOwner {
        require(_exists(uuid), "Invalid UUID");
        positions[uuid].active = false;
        delete positions[uuid];
        delete positionOwner[uuid];
        _burn(uuid);
    }
}
