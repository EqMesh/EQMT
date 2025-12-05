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

    constructor()
        ERC721("EqMesh Position Token", "EQMT")
        Ownable(msg.sender)
    {}

    // ----------------------------------------------------------------------
    // SOULBOUND LOGIC (OpenZeppelin v5 compliant)
    // ----------------------------------------------------------------------
    // _update() is the universal transfer hook in OZ v5.
    // This method handles:
    // - mint (from = 0)
    // - burn (to = 0)
    // - transfer (both non-zero)
    // We block ALL user transfers unless the admin (owner) initiates them.
    // ----------------------------------------------------------------------

    function _update(
        address to,
        uint256 tokenId,
        address auth
    ) internal virtual override returns (address) {

        address from = _ownerOf(tokenId);

        bool isMint = from == address(0);
        bool isBurn = to == address(0);

        // Allow mint and burn unconditionally
        if (!isMint && !isBurn) {
            // This is a TRANSFER. Reject unless sender = contract owner (admin).
            require(msg.sender == owner(), "Transfers restricted to admin only");
        }

        return super._update(to, tokenId, auth);
    }

    // ----------------------------------------------------------------------
    // CLIENT-FRIENDLY EQMT OPERATIONS
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

    // Reassign EQMT ownership internally
    function clientPositionTransfer(uint256 uuid, address newOwner) external onlyOwner {
        require(_ownerOf(uuid) != address(0), "Invalid UUID");

        positionOwner[uuid] = newOwner;

        // Admin transfer is allowed by _update override
        _update(newOwner, uuid, msg.sender);
    }

    // Replace creditProfit → creditEQMT
    function creditEQMT(uint256 uuid) external payable onlyOwner {
        require(_ownerOf(uuid) != address(0), "Invalid UUID");
        require(positions[uuid].active, "Position closed");

        positions[uuid].equityBalance += msg.value;
    }

    // Replace withdrawProfit → liquidateEQMT
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
