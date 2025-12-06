// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts@4.7.0/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts@4.7.0/utils/Strings.sol";
import "@openzeppelin/contracts@4.7.0/utils/Base64.sol";

contract EQMT is ERC721 {
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

function tokenURI(uint256 tokenId)
    public
    view
    override
    returns (string memory)
{
    require(_exists(tokenId), "Invalid token");
    string memory uuid = tokenIdToUUID[tokenId];
    Strategy memory p = strategies[uuid];

    string memory json = string(
        abi.encodePacked(
            "{",
                '"name":"EqMesh Strategy Token #', Strings.toString(tokenId), '",',
                '"description":"EQMT is a eth-backed Strategy token. Each token represents a financial Strategy run on eqmesh.com.",',
                '"image":"https://eqmesh.com/static/images/logo-250.png",',
                '"external_url":"https://eqmesh.com/token",',
                '"attributes":[',
                    '{"trait_type":"Sanity","value":"', p.sanity, '"},',
                "]",
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

mapping(string => Strategy) public strategies;
mapping(address => string) public activeUUID;
mapping(uint256 => string) public tokenIdToUUID;

event EQMTMinted(
        bytes32 indexed uuidHash,
        string uuid,
        address owner,
        uint16 fcid,
        string sanity,
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

    modifier strategyExists(string memory uuid) {
        require(strategies[uuid].owner != address(0), "No Strategy");
        _;
    }

    
 function _beforeTokenTransfer(
    address from, 
    address to, 
    uint256 tokenId
    ) internal override virtual {
    require(from == address(0), "Err: no Private Transfers!"); 
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
        require(from == address(0) || to == address(0), "No Transfers");
        super._transfer(from, to, tokenId);
    }

    function _safeTransfer(
        address from,
        address to,
        uint256 tokenId,
        bytes memory _data
    ) internal virtual override {
        require(from == address(0) || to == address(0), "No Transfers");
        super._safeTransfer(from, to, tokenId, _data);
    }

    function mintEQMT(
        string calldata uuid,
        address wallet,
        uint16 fcid,
        string calldata sanity
    )
        external
        onlyAdmin
    {
        string memory oldUUID = activeUUID[wallet];
        if (bytes(oldUUID).length > 0 && strategies[oldUUID].active) {
            strategies[oldUUID].active = false;
            emit EQMTClosed(keccak256(bytes(oldUUID)), oldUUID, strategies[oldUUID].tokenId);
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

        emit EQMTMinted(
            keccak256(bytes(uuid)),
            uuid,
            wallet,
            fcid,
            sanity,
            tokenId
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

        emit EQMTCredited(
            keccak256(bytes(uuid)),
            uuid,
            msg.value,
            ref,
            strategies[uuid].tokenId
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
        if (bytes(oldUUID).length > 0 && strategies[oldUUID].active) {
            strategies[oldUUID].active = false;
            emit EQMTClosed(keccak256(bytes(oldUUID)), oldUUID, strategies[oldUUID].tokenId);
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
        strategyExists(uuid)
    {
        strategies[uuid].active = false;
        emit EQMTClosed(keccak256(bytes(uuid)), uuid, strategies[uuid].tokenId);
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
        emit EQMTBurned(keccak256(bytes(uuid)), uuid, tokenId);
    }

    function liquidateEQMT(string calldata uuid)
        external
        strategyExists(uuid)
    {
        Strategy storage p = strategies[uuid];

        require(p.owner == msg.sender, "Not owner");
        require(p.active, "Strategy closed");
        require(p.equity > 0, "No balance");

        uint256 amount = p.equity;
        p.equity = 0;

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

    function getStrategy(string calldata uuid)
        external
        view
        returns (Strategy memory)
    {
        return strategies[uuid];
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
        return strategies[uuid].tokenId;
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
