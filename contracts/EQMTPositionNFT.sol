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
    // SOULBOUND RESTRICTIONS (OZ v5-compliant)
    // ----------------------------------------------------------------------
    // This hook is called for MINT, BURN, and TRANSFER
    // We allow:
    // - Mint (from == 0)
    // - Burn (to == 0)
    // - Admin transfers only (msg.sender == owner())
    // We reject:
    // - Any user-initiated transfer
    // ----------------------------------------------------------------------
    function _update(
        address to,
        uint256 tokenId,
        address auth
    ) internal virtual override returns (address) {
        
        address from = _ownerOf(tokenId);

        bool isMint = from == address(0);
        bool isBurn = to == address(0);

        if (!isMint && !isBurn) {
            // Block all user transfers
            require(msg.sender == owner(), "Transfers restricted to admin only");
        }

        return super._update(to, tokenId, auth);
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

    // Renamed from adminReassign -> clientPositionTransfer
    function clientPositionTransfer(uint256 uuid, address newOwner) external onlyOwner {
        require(_ownerOf(uuid) != address(0), "Invalid UUID");

        positionOwner[uuid] = newOwner;

        // Admin transfer uses internal hook which allows owner() calls
        _update(newOwner, uuid, msg.sender);
    }

    // Renamed from creditProfit -> creditEQMT
    function creditEQMT(uint256 uuid) external payable onlyOwner {
        require(_ownerOf(uuid) != address(0), "Invalid UUID");
        require(positions[uuid].active, "Position closed");

        positions[uuid].equityBalance += msg.value;
    }

    // Renamed from withdrawProfit -> liquidateEQMT
    function liquidateEQMT(uint256 uuid) external {
        require(_ownerOf(uuid) != address(0), "Invalid UUID");
        require(msg.sender == positionOwner[uuid], "Not position owner");

        uint256 amount = positions[uuid].equityBalance;
        require(amount > 0, "No funds available");

        positions[uuid].equityBalance = 0;

        (bool success, ) = payable(msg.sender).call{value: amount}("");
        require(success, "ETH transfer failed");
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
