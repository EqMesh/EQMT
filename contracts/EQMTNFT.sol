// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts@4.7.0/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts@4.7.0/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts@4.7.0/access/Ownable.sol";
import "@openzeppelin/contracts@4.7.0/utils/Counters.sol";
import "@openzeppelin/contracts@4.7.0/utils/Strings.sol";
import "@openzeppelin/contracts@4.7.0/utils/Base64.sol";

contract EQMTNFT3 is ERC721 {
    address public admin;
    string private constant TOKEN_IMAGE =
        "https://eqmesh.com/static/images/logo-250.png";
    uint256 private _tokenIdCounter;

    struct Position {
        uint16 fcid;
        string sanity;
        string uuid;
        uint256 baseequity;
        uint256 equityBalance;
        bool active;
        address owner;
        uint256 tokenId;
    }

    mapping(string => Position) public positions;
    mapping(address => string) public activeUUID;
    mapping(uint256 => string) public tokenIdToUUID;

    event EQMTMinted(
        bytes32 indexed uuidHash,
        string uuid,
        address owner,
        uint16 fcid,
        string sanity,
        uint256 baseequity,
        uint256 tokenId
    );

    event EQMTCredited(
        bytes32 indexed uuidHash,
        string uuid,
        uint256 amount,
        string ref,
        uint256 tokenId
    );

    event EQMTLiquidated(
        bytes32 indexed uuidHash,
        string uuid,
        uint256 amount,
        address to,
        uint256 tokenId
    );

    event EQMTOwnerChanged(
        bytes32 indexed uuidHash,
        string uuid,
        address from,
        address to,
        uint256 tokenId
    );

    event EQMTClosed(bytes32 indexed uuidHash, string uuid, uint256 tokenId);
    event EQMTBurned(bytes32 indexed uuidHash, string uuid, uint256 tokenId);

    modifier onlyAdmin() {
        require(msg.sender == admin, "Admin only");
        _;
    }

    modifier positionExists(string memory uuid) {
        require(positions[uuid].owner != address(0), "Position does not exist");
        _;
    }

    constructor() ERC721("EqMesh Strategy Token", "EQMT") {
        admin = msg.sender;
    }

    // --------------------------------------------------------
    // ERC721 METADATA — tokenURI()
    // --------------------------------------------------------
    function tokenURI(uint256 tokenId)
    public
    view
    override
    returns (string memory)
{
    require(_exists(tokenId), "Invalid token");
    string memory uuid = tokenIdToUUID[tokenId];
    Position memory p = positions[uuid];

    string memory json = string(
        abi.encodePacked(
            "{",
                '"name":"EqMesh Strategy Token #', Strings.toString(tokenId), '",',
                '"description":"EQMT are non-transferable, the ETH comes with it are yours to keep!",',
                '"image":"', TOKEN_IMAGE, '",',
                '"fcid":', Strings.toString(p.fcid), ',',
                '"sanity":"', p.sanity, '",',
                '"baseequity":', Strings.toString(p.baseequity), ',',
                '"equityBalance":', Strings.toString(p.equityBalance),
            "}"
        )
    );

    return string(
        abi.encodePacked(
            "data:application/json;base64,",
            Base64.encode(bytes(json))
        )
    );

    }
        
                // Solution: Remove override and implement custom transfer blocking
 function _beforeTokenTransfer(
    address from, 
    address to, 
    uint256 tokenId
    ) internal override virtual {
    require(from == address(0), "Err: token transfer is BLOCKED"); 
    super._beforeTokenTransfer(from, to, tokenId);  
    }

    // Required for ERC721 compliance
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    // Override transfer functions to block transfers
    function _transfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual override {
        require(from == address(0) || to == address(0), "Transfers disabled");
        super._transfer(from, to, tokenId);
    }

    function _safeTransfer(
        address from,
        address to,
        uint256 tokenId,
        bytes memory _data
    ) internal virtual override {
        require(from == address(0) || to == address(0), "Transfers disabled");
        super._safeTransfer(from, to, tokenId, _data);
    }

    function mintEQMT(
        string calldata uuid,
        address wallet,
        uint16 fcid,
        string calldata sanity,
        uint256 baseequity
    )
        external
        onlyAdmin
    {
        string memory oldUUID = activeUUID[wallet];
        if (bytes(oldUUID).length > 0 && positions[oldUUID].active) {
            positions[oldUUID].active = false;
            emit EQMTClosed(keccak256(bytes(oldUUID)), oldUUID, positions[oldUUID].tokenId);
        }

        uint256 tokenId = _tokenIdCounter++;
        _safeMint(wallet, tokenId);

        positions[uuid] = Position({
            fcid: fcid,
            sanity: sanity,
            uuid: uuid,
            baseequity: baseequity,
            equityBalance: 0,
            active: true,
            owner: wallet,
            tokenId: tokenId
        });

        activeUUID[wallet] = uuid;
        tokenIdToUUID[tokenId] = uuid;

        emit EQMTMinted(
            keccak256(bytes(uuid)),
            uuid,
            wallet,
            fcid,
            sanity,
            baseequity,
            tokenId
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
            ref,
            positions[uuid].tokenId
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
            emit EQMTClosed(keccak256(bytes(oldUUID)), oldUUID, positions[oldUUID].tokenId);
        }

        // Use internal transfer which we've overridden
        super._transfer(oldWallet, newWallet, p.tokenId);

        p.owner = newWallet;
        activeUUID[newWallet] = uuid;

        emit EQMTOwnerChanged(
            keccak256(bytes(uuid)),
            uuid,
            oldWallet,
            newWallet,
            p.tokenId
        );
    }

    function closeEQMT(string calldata uuid)
        external
        onlyAdmin
        positionExists(uuid)
    {
        positions[uuid].active = false;
        emit EQMTClosed(keccak256(bytes(uuid)), uuid, positions[uuid].tokenId);
    }

    function burnEQMT(string calldata uuid)
        external
        onlyAdmin
        positionExists(uuid)
    {
        uint256 tokenId = positions[uuid].tokenId;
        _burn(tokenId);
        delete tokenIdToUUID[tokenId];
        delete positions[uuid];
        emit EQMTBurned(keccak256(bytes(uuid)), uuid, tokenId);
    }

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
            msg.sender,
            p.tokenId
        );
    }

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

    function getTokenIdForUUID(string calldata uuid)
        external
        view
        returns (uint256)
    {
        return positions[uuid].tokenId;
    }

    function getUUIDForTokenId(uint256 tokenId)
        external
        view
        returns (string memory)
    {
        return tokenIdToUUID[tokenId];
    }

    function ownerOfTokenId(uint256 tokenId)
        external
        view
        returns (address)
    {
        return ownerOf(tokenId);
    }



}
