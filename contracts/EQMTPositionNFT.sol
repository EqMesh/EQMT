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
    // SOULBOUND (NON-TRANSFERABLE) OVERRIDES
    // ----------------------------------------------------------------------
    function _transfer(address, address, uint256) internal pure override {
        revert("EQMT positions are non-transferable");
    }

    function approve(address, uint256) public pure override {
        revert("EQMT positions are non-transferable");
    }

    function setApprovalForAll(address, bool) public pure override {
        revert("EQMT positions are non-transferable");
    }

    // ----------------------------------------------------------------------
    // CLIENT-FRIENDLY POSITION OPERATIONS
    // ----------------------------------------------------------------------

    // Mint a new EQMT position (admin only)
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

    // Transfer EQMT position ownership (admin-controlled)
    // Renamed from adminReassign
    function clientPositionTransfer(uint256 uuid, address newOwner) external onlyOwner {
        require(_ownerOf(uuid) != address(0), "Invalid UUID");

        positionOwner[uuid] = newOwner;
        _safeTransfer(ownerOf(uuid), newOwner, uuid, "");
    }

    // Add ETH to the position balance
    // Renamed from creditProfit
    function creditEQMT(uint256 uuid) external payable onlyOwner {
        require(_ownerOf(uuid) != address(0), "Invalid UUID");
        require(positions[uuid].active, "Position closed");

        positions[uuid].equityBalance += msg.value;
    }

    // Withdraw ETH from a position
    // Renamed from withdrawProfit
    function liquidateEQMT(uint256 uuid) external {
        require(_ownerOf(uuid) != address(0), "Invalid UUID");
        require(msg.sender == positionOwner[uuid], "Not position owner");

        uint256 amount = positions[uuid].equityBalance;
        require(amount > 0, "No funds available");

        positions[uuid].equityBalance = 0;

        (bool sent, ) = payable(msg.sender).call{value: amount}("");
        require(sent, "ETH transfer failed");
    }

    // Close the EQMT (admin)
    function closeEQMT(uint256 uuid) external onlyOwner {
        require(_ownerOf(uuid) != address(0), "Invalid UUID");
        positions[uuid].active = false;
    }

    // Permanently burn the EQMT (admin)
    function burnEQMT(uint256 uuid) external onlyOwner {
        require(_ownerOf(uuid) != address(0), "Invalid UUID");

        positions[uuid].active = false;
        delete positions[uuid];
        delete positionOwner[uuid];

        _burn(uuid);
    }
}
