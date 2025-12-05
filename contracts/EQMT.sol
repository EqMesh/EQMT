// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

contract EQMT {

    address public admin;

    struct Position {
        uint16 fcid;
        uint64 bid;
        string sanity;
        uint256 baseequity;
        uint256 equityBalance;
        bool active;
        address owner;
    }

    // UUID → Position
    mapping(string => Position) public positions;

    // Wallet → currently active UUID (for fast lookup)
    mapping(address => string) public activeUUID;

    // ------------------------ EVENTS ------------------------

    event EQMTMinted(
        string uuid,
        address owner,
        uint16 fcid,
        uint64 bid,
        string sanity,
        uint256 baseequity
    );

    event EQMTCredited(
        string uuid,
        uint256 amount,
        string ref
    );

    event EQMTLiquidated(
        string uuid,
        uint256 amount,
        address to
    );

    event EQMTOwnerChanged(
        string uuid,
