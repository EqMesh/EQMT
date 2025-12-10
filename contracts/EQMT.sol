// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "@openzeppelin/contracts@4.7.0/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts@4.7.0/utils/Strings.sol";

contract EQMT is ERC721 {
    address private constant previousContract = 0x1988cB209d705F49982E1a13842a7b684A281e58;
    string private constant version = "0.201";
    
    address public admin;
    uint256 private _tokenIdCounter;

    struct Strategy {
        uint16 fcid;
        string sanity;
        string uuid;
        uint256 equity;
        bool active;
        address owner;
        uint256 tokenId;
    }

    constructor() ERC721("EqMesh Strategy Token", "EQMT") {
        admin = msg.sender;
    }

    /// @notice Contract-level metadata URL: https://eqmesh.com/token/<contractAddress>.json
    function contractURI() public view returns (string memory) {
        return string(
            abi.encodePacked(
                "https://eqmesh.com/token/EQMT/meta/",
                Strings.toHexString(uint160(address(this)), 20),
                ".json"
            )
        );
    }

    /// @notice Token-level metadata; all tokens share the same JSON for this contract.
    function tokenURI(uint256 tokenId)
        public
        view
        override
        returns (string memory)
    {
        require(_exists(tokenId), "ERC721Metadata: No Token");
        return contractURI();
    }
        

mapping(string => Strategy) public strategies;
mapping(address => string) public activeUUID;
mapping(uint256 => string) public tokenIdToUUID;

event EQMTEvent(
    bytes32 indexed uuidHash,   // topic1
    uint256 indexed tokenId,    // topic2
    uint8 action,               // 1=mint,2=credit,3=liquidate,4=close,5=burn,6=ownerChange,9=adminUpdate
    uint256 amount,             // credit/liquidate only, otherwise 0
    address addr1,              // mint: owner | liquidate: to | ownerChange: from
    address addr2,              // sownerChange: to | others: zero address
    string uuid,                // uuid (plaintext)
    string meta                 // JSON or string with extra data
);


modifier onlyAdmin() {
    require(msg.sender == admin, "Admin only");
    _;
}

modifier strategyExists(string memory uuid) {
    require(strategies[uuid].owner != address(0), "No Strategy");
    _;
}

function _beforeTokenTransfer(address from, address to, uint256 tokenId)
    internal
    override
{
    // Allow minting OR admin-performed transfers
    if (!(from == address(0) || msg.sender == admin)) {
        revert("Err: no Private Transfers!");
    }
    super._beforeTokenTransfer(from, to, tokenId);
}

// Override transfer functions to block transfers
function _transfer(address from, address to, uint256 tokenId)
    internal
    override
{
    // Allow mint OR admin override
    if (!(from == address(0) || msg.sender == admin)) {
        revert("No Transfers");
    }
    super._transfer(from, to, tokenId);
}

// Actual Token Functions 
function mintEQMT
    (
        string calldata uuid,
        address wallet,
        uint16 fcid,
        string calldata sanity
    )
    external
    onlyAdmin
{
    string memory oldUUID = activeUUID[wallet];
    if (bytes(oldUUID).length >= 1) {
        if (strategies[oldUUID].active) {
            strategies[oldUUID].active = false;

            emit EQMTEvent(
                keccak256(bytes(oldUUID)),
                strategies[oldUUID].tokenId,
                4,
                0,
                wallet,
                address(0),
                oldUUID,
                ""
            );
        }
    }

    uint256 tokenId = _tokenIdCounter++;
    _safeMint(wallet, tokenId);

    strategies[uuid] = Strategy({
        fcid: fcid,
        sanity: sanity,
        uuid: uuid,
        equity: 0,
        active: true,
        owner: wallet,
        tokenId: tokenId
    });
    
    activeUUID[wallet] = uuid;
    tokenIdToUUID[tokenId] = uuid;

    emit EQMTEvent(
        keccak256(bytes(uuid)),
        tokenId,
        1,
        0,
        wallet,
        address(0),
        uuid,
        string(
            abi.encodePacked(
                '{"action":"mint","fcid":', Strings.toString(fcid),
                ',"sanity":"', sanity, '"}'
            )
        )
    );
}

function creditEQMT(string calldata uuid, string calldata ref)
    external
    payable
    onlyAdmin
    strategyExists(uuid)
{
    require(strategies[uuid].active, "Strategy closed");
    require(msg.value > 0, "No ETH sent");
    strategies[uuid].equity += msg.value;
    uint256 tokenId = strategies[uuid].tokenId;

    emit EQMTEvent(
        keccak256(bytes(uuid)),
        tokenId,
        2,
        msg.value,
        address(0),
        address(0),
        uuid,
        ref
    );
}

function adminReassign(string calldata uuid, address newWallet)
    external
    onlyAdmin
    strategyExists(uuid)
{
    Strategy storage p = strategies[uuid];
    address oldWallet = p.owner;
    string memory oldUUID = activeUUID[newWallet];
    if (bytes(oldUUID).length >= 1) {
        if (strategies[oldUUID].active) {
            strategies[oldUUID].active = false;

        // this needs to be reassigned to the new Event call!!
            emit EQMTEvent(
                keccak256(bytes(uuid)),
                strategies[oldUUID].tokenId,
                4,
                0,
                address(0),
                address(0),
                uuid,
                ""
            );
        }
    }

    // Use internal transfer which we've overridden
    super._transfer(oldWallet, newWallet, p.tokenId);
    p.owner = newWallet;
    activeUUID[newWallet] = uuid;

    uint256 tokenId = strategies[uuid].tokenId;
    emit EQMTEvent(
        keccak256(bytes(uuid)),
        tokenId,
        6,
        0,
        oldWallet,
        newWallet,
        uuid,
        ""
    );
}

// Emergency admin switch – use sparingly.
// Does NOT update activeUUID, just flips the flag.
function adminSetActive(uint256 tokenId, bool isActive)
    external
    onlyAdmin
{
    string memory uuid = tokenIdToUUID[tokenId];
    require(bytes(uuid).length > 0, "UUID missing");

    Strategy storage s = strategies[uuid];
    address w = s.owner;
    s.active = isActive;

    if (isActive) {
        // you are explicitly saying "this is the active one for this wallet"
        activeUUID[w] = uuid;
    } else if (keccak256(bytes(activeUUID[w])) == keccak256(bytes(uuid))) {
        // if this was marked active, clear it
        activeUUID[w] = "";
    }
    // we need some logging here! (event 9 should do it)

}

function closeEQMT(string calldata uuid)
    external
    onlyAdmin
    strategyExists(uuid)
{
    strategies[uuid].active = false;
    uint256 tokenId = strategies[uuid].tokenId;
    emit EQMTEvent(
        keccak256(bytes(uuid)),
        tokenId,
        4,
        0,
        address(0),
        address(0),
        uuid,
        ""
    );
}

function burnEQMT(string calldata uuid)
    external
    onlyAdmin
    strategyExists(uuid)
{
    uint256 tokenId = strategies[uuid].tokenId;
    _burn(tokenId);
    delete tokenIdToUUID[tokenId];
    delete strategies[uuid];

    emit EQMTEvent(
        keccak256(bytes(uuid)),
        tokenId,
        5,
        0,
        address(0),
        address(0),
        uuid,
        ""
    );
}

function liquidateEQMT(string calldata uuid) external {
    Strategy storage s = strategies[uuid];
    require(s.owner != address(0), "No strategy");

    uint256 tokenId = s.tokenId;
    require(_exists(tokenId), "Invalid token");

    address owner = ownerOf(tokenId);
    require(owner == s.owner, "Owner mismatch");

    // allow owner or admin to trigger; always pay owner
    require(
        msg.sender == owner || msg.sender == admin,
        "Not owner or admin"
    );

    require(s.equity > 0, "No equity to liquidate");

    uint256 amount = s.equity;
    s.equity = 0;

    (bool ok, ) = owner.call{value: amount}("");
    require(ok, "ETH transfer failed");

    emit EQMTEvent(
        keccak256(bytes(uuid)),
        tokenId,
        3,
        amount,
        owner,
        address(0),
        uuid,
        ""
    );
}
}