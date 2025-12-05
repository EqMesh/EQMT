// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract LockedValueNFT is ERC721, Ownable, ReentrancyGuard {
    uint256 private _nextId;

    // --------------------------------------------------------
    // DATA STRUCTURES
    // --------------------------------------------------------
    struct TokenInfo {
        string fcid;       // permanent at mint
        string sanity;     // admin-updatable
        string strategy;   // admin-updatable
    }

    // tokenId → metadata
    mapping(uint256 => TokenInfo) public info;

    // tokenId → ETH balance
    mapping(uint256 => uint256) public balanceOfToken;

    // --------------------------------------------------------
    // EVENTS
    // --------------------------------------------------------
    event TokenCredited(uint256 indexed tokenId, uint256 amount, address indexed admin);
    event TokenLiquidated(uint256 indexed tokenId, uint256 amount, address indexed owner);
    event NFTOwnershipMoved(uint256 indexed tokenId, address indexed from, address indexed to);
    event SanityUpdated(uint256 indexed tokenId, string newSanity);
    event StrategyUpdated(uint256 indexed tokenId, string newStrategy);
    event TokenBurned(uint256 indexed tokenId, uint256 ethReturnedToAdmin);

    // --------------------------------------------------------
    // CONSTRUCTOR
    // --------------------------------------------------------
    constructor()
        ERC721("LockedValueNFT", "LVNFT")
        Ownable(msg.sender)
    {}

    // --------------------------------------------------------
    // INTERNAL CHECK
    // --------------------------------------------------------
    function _tokenExists(uint256 tokenId) internal view returns (bool) {
        return _ownerOf(tokenId) != address(0);
    }

    // --------------------------------------------------------
    // MINTING
    // --------------------------------------------------------
    function mint(
        address to,
        string memory fcid,
        string memory sanityInitial,
        string memory strategyInitial
    )
        external
        onlyOwner
        returns (uint256)
    {
        uint256 tokenId = ++_nextId;

        _mint(to, tokenId);

        info[tokenId] = TokenInfo({
            fcid: fcid,
            sanity: sanityInitial,
            strategy: strategyInitial
        });

        return tokenId;
    }

    // --------------------------------------------------------
    // ADMIN — Update sanity
    // --------------------------------------------------------
    function updateSanity(uint256 tokenId, string calldata newSanity)
        external
        onlyOwner
    {
        require(_tokenExists(tokenId), "Invalid token");

        info[tokenId].sanity = newSanity;

        emit SanityUpdated(tokenId, newSanity);
    }

    // --------------------------------------------------------
    // ADMIN — Update strategy
    // --------------------------------------------------------
    function updateStrategy(uint256 tokenId, string calldata newStrategy)
        external
        onlyOwner
    {
        require(_tokenExists(tokenId), "Invalid token");

        info[tokenId].strategy = newStrategy;

        emit StrategyUpdated(tokenId, newStrategy);
    }

    // --------------------------------------------------------
    // VIEW — Get all token data
    // --------------------------------------------------------
    function getTokenData(uint256 tokenId)
        external
        view
        returns (
            string memory fcid,
            string memory sanity,
            string memory strategy,
            uint256 ethBalance,
            address ownerAddress
        )
    {
        require(_tokenExists(tokenId), "Invalid token");

        TokenInfo memory t = info[tokenId];

        return (
            t.fcid,
            t.sanity,
            t.strategy,
            balanceOfToken[tokenId],
            ownerOf(tokenId)
        );
    }

    // --------------------------------------------------------
    // ADMIN — Move ownership (soulbound for users)
    // --------------------------------------------------------
    function adminMoveToken(uint256 tokenId, address newOwner)
        external
        onlyOwner
    {
        require(_tokenExists(tokenId), "Invalid token");

        address oldOwner = ownerOf(tokenId);
        _transfer(oldOwner, newOwner, tokenId);

        emit NFTOwnershipMoved(tokenId, oldOwner, newOwner);
    }

    // --------------------------------------------------------
    // ADMIN — CREDIT TOKEN (deposit ETH)
    // --------------------------------------------------------
    function creditToken(uint256 tokenId)
        external
        payable
        onlyOwner
    {
        require(_tokenExists(tokenId), "Invalid token");
        require(msg.value > 0, "No ETH sent");

        balanceOfToken[tokenId] += msg.value;

        emit TokenCredited(tokenId, msg.value, msg.sender);
    }

    // --------------------------------------------------------
    // OWNER — LIQUIDATE TOKEN (withdraw ETH to owner ONLY)
    // --------------------------------------------------------
    function liquidateToken(uint256 tokenId, uint256 amount)
        external
        nonReentrant
    {
        require(_tokenExists(tokenId), "Invalid token");

        address ownerAddr = ownerOf(tokenId);

        require(msg.sender == ownerAddr, "Not NFT owner");
        require(amount > 0, "Amount must be >0");
        require(balanceOfToken[tokenId] >= amount, "Insufficient balance");

        balanceOfToken[tokenId] -= amount;

        (bool ok, ) = ownerAddr.call{value: amount}("");
        require(ok, "ETH transfer failed");

        emit TokenLiquidated(tokenId, amount, ownerAddr);
    }

    // --------------------------------------------------------
    // ADMIN — BURN TOKEN & reclaim all ETH
    // --------------------------------------------------------
    function adminBurn(uint256 tokenId)
        external
        onlyOwner
        nonReentrant
    {
        require(_tokenExists(tokenId), "Invalid token");

        uint256 amount = balanceOfToken[tokenId];
        balanceOfToken[tokenId] = 0;

        // Refund ETH to admin
        if (amount > 0) {
            (bool ok, ) = owner().call{value: amount}("");
            require(ok, "ETH refund failed");
        }

        delete info[tokenId];

        _burn(tokenId);

        emit TokenBurned(tokenId, amount);
    }

    // --------------------------------------------------------
    // SOULBOUND — Block transfers for users
    // --------------------------------------------------------
    function _update(address to, uint256 tokenId, address auth)
        internal
        virtual
        override
        returns (address)
    {
        address from = _ownerOf(tokenId);

        // If caller is not admin AND token is not being minted, block transfer
        if (auth != owner()) {
            if (from != address(0)) {
                revert("This NFT is non-transferable");
            }
        }

        return super._update(to, tokenId, auth);
    }

    // --------------------------------------------------------
    // BLOCK APPROVALS
    // --------------------------------------------------------
    function approve(address, uint256) public pure override {
        revert("Approvals disabled");
    }

    function setApprovalForAll(address, bool) public pure override {
        revert("Approvals disabled");
    }

    // --------------------------------------------------------
    // BLOCK DIRECT ETH SENDS
    // --------------------------------------------------------
    receive() external payable {
        revert("Direct ETH not allowed; use creditToken");
    }

    fallback() external payable {
        revert("Direct ETH not allowed; use creditToken");
    }
}
