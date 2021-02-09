// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

import "./HashBridgeOracle.sol";
import "./interfaces/ENSInterface.sol";
import "./interfaces/HashBridgeOracleTokenInterface.sol";
import "./interfaces/HashBridgeOracleRequestInterface.sol";
import "./interfaces/PointerInterface.sol";
import {
    ENSResolver as ENSResolver_HashBridgeOracle
} from "./vendor/ENSResolver.sol";

/**
 * @title The HashBridgeOracleClient contract
 * @notice Contract writers can inherit this contract in order to create requests for the
 * HashBridgeOracle network
 */
contract HashBridgeOracleClient {
    using HashBridgeOracle for HashBridgeOracle.Request;

    uint256 internal constant HBO = 10**18;
    uint256 private constant AMOUNT_OVERRIDE = 0;
    address private constant SENDER_OVERRIDE = address(0);
    uint256 private constant ARGS_VERSION = 1;
    bytes32 private constant ENS_TOKEN_SUBNAME = keccak256("hbo");
    bytes32 private constant ENS_ORACLE_SUBNAME = keccak256("oracle");
    address private constant HBO_TOKEN_POINTER =
        0xC89bD4E1632D3A43CB03AAAd5262cbe4038Bc571;

    ENSInterface private ens;
    bytes32 private ensNode;
    HashBridgeOracleTokenInterface private hbo;
    HashBridgeOracleRequestInterface private oracle;
    uint256 private requestCount = 1;
    mapping(bytes32 => address) private pendingRequests;

    event HashBridgeOracleRequested(bytes32 indexed id);
    event HashBridgeOracleFulfilled(bytes32 indexed id);
    event HashBridgeOracleCancelled(bytes32 indexed id);

    /**
     * @notice Creates a request that can hold additional parameters
     * @param _specId The Job Specification ID that the request will be created for
     * @param _callbackAddress The callback address that the response will be sent to
     * @param _callbackFunctionSignature The callback function signature to use for the callback address
     * @return A HashBridgeOracle Request struct in memory
     */
    function buildHashBridgeOracleRequest(
        bytes32 _specId,
        address _callbackAddress,
        bytes4 _callbackFunctionSignature
    ) internal pure returns (HashBridgeOracle.Request memory) {
        HashBridgeOracle.Request memory req;
        return
            req.initialize(
                _specId,
                _callbackAddress,
                _callbackFunctionSignature
            );
    }

    /**
     * @notice Creates a HashBridgeOracle request to the stored oracle address
     * @dev Calls `hashBridgeOracleRequestTo` with the stored oracle address
     * @param _req The initialized HashBridgeOracle Request
     * @param _payment The amount of HBO to send for the request
     * @return requestId The request ID
     */
    function sendHashBridgeOracleRequest(
        HashBridgeOracle.Request memory _req,
        uint256 _payment
    ) internal returns (bytes32) {
        return sendHashBridgeOracleRequestTo(address(oracle), _req, _payment);
    }

    /**
     * @notice Creates a HashBridgeOracle request to the specified oracle address
     * @dev Generates and stores a request ID, increments the local nonce, and uses `transferAndCall` to
     * send HBO which creates a request on the target oracle contract.
     * Emits HashBridgeOracleRequested event.
     * @param _oracle The address of the oracle for the request
     * @param _req The initialized HashBridgeOracle Request
     * @param _payment The amount of HBO to send for the request
     * @return requestId The request ID
     */
    function sendHashBridgeOracleRequestTo(
        address _oracle,
        HashBridgeOracle.Request memory _req,
        uint256 _payment
    ) internal returns (bytes32 requestId) {
        requestId = keccak256(abi.encodePacked(this, requestCount));
        _req.nonce = requestCount;
        pendingRequests[requestId] = _oracle;
        emit HashBridgeOracleRequested(requestId);
        require(
            hbo.transferAndCall(_oracle, _payment, encodeRequest(_req)),
            "unable to transferAndCall to oracle"
        );
        requestCount += 1;

        return requestId;
    }

    /**
     * @notice Allows a request to be cancelled if it has not been fulfilled
     * @dev Requires keeping track of the expiration value emitted from the oracle contract.
     * Deletes the request from the `pendingRequests` mapping.
     * Emits HashBridgeOracleCancelled event.
     * @param _requestId The request ID
     * @param _payment The amount of HBO sent for the request
     * @param _callbackFunc The callback function specified for the request
     * @param _expiration The time of the expiration for the request
     */
    function cancelHashBridgeOracleRequest(
        bytes32 _requestId,
        uint256 _payment,
        bytes4 _callbackFunc,
        uint256 _expiration
    ) internal {
        HashBridgeOracleRequestInterface requested =
            HashBridgeOracleRequestInterface(pendingRequests[_requestId]);
        delete pendingRequests[_requestId];
        emit HashBridgeOracleCancelled(_requestId);
        requested.cancelOracleRequest(
            _requestId,
            _payment,
            _callbackFunc,
            _expiration
        );
    }

    /**
     * @notice Sets the stored oracle address
     * @param _oracle The address of the oracle contract
     */
    function setHashBridgeOracleOracle(address _oracle) internal {
        oracle = HashBridgeOracleRequestInterface(_oracle);
    }

    /**
     * @notice Sets the HBO token address
     * @param _hbo The address of the HBO token contract
     */
    function setHashBridgeOracleToken(address _hbo) internal {
        hbo = HashBridgeOracleTokenInterface(_hbo);
    }

    /**
     * @notice Sets the HashBridgeOracle token address for the public
     * network as given by the Pointer contract
     */
    function setPublicHashBridgeOracleToken() internal {
        setHashBridgeOracleToken(
            PointerInterface(HBO_TOKEN_POINTER).getAddress()
        );
    }

    /**
     * @notice Retrieves the stored address of the HBO token
     * @return The address of the HBO token
     */
    function hashBridgeOracleTokenAddress() internal view returns (address) {
        return address(hbo);
    }

    /**
     * @notice Retrieves the stored address of the oracle contract
     * @return The address of the oracle contract
     */
    function hashBridgeOracleAddress() internal view returns (address) {
        return address(oracle);
    }

    /**
     * @notice Allows for a request which was created on another contract to be fulfilled
     * on this contract
     * @param _oracle The address of the oracle contract that will fulfill the request
     * @param _requestId The request ID used for the response
     */
    function addHashBridgeOracleExternalRequest(
        address _oracle,
        bytes32 _requestId
    ) internal notPendingRequest(_requestId) {
        pendingRequests[_requestId] = _oracle;
    }

    /**
     * @notice Sets the stored oracle and HBO token contracts with the addresses resolved by ENS
     * @dev Accounts for subnodes having different resolvers
     * @param _ens The address of the ENS contract
     * @param _node The ENS node hash
     */
    function useHashBridgeOracleWithENS(address _ens, bytes32 _node) internal {
        ens = ENSInterface(_ens);
        ensNode = _node;
        bytes32 hboSubnode =
            keccak256(abi.encodePacked(ensNode, ENS_TOKEN_SUBNAME));
        ENSResolver_HashBridgeOracle resolver =
            ENSResolver_HashBridgeOracle(ens.resolver(hboSubnode));
        setHashBridgeOracleToken(resolver.addr(hboSubnode));
        updateHashBridgeOracleOracleWithENS();
    }

    /**
     * @notice Sets the stored oracle contract with the address resolved by ENS
     * @dev This may be called on its own as long as `useHashBridgeOracleWithENS` has been called previously
     */
    function updateHashBridgeOracleOracleWithENS() internal {
        bytes32 oracleSubnode =
            keccak256(abi.encodePacked(ensNode, ENS_ORACLE_SUBNAME));
        ENSResolver_HashBridgeOracle resolver =
            ENSResolver_HashBridgeOracle(ens.resolver(oracleSubnode));
        setHashBridgeOracleOracle(resolver.addr(oracleSubnode));
    }

    /**
     * @notice Encodes the request to be sent to the oracle contract
     * @dev The HashBridgeOracle node expects values to be in order for the request to be picked up. Order of types
     * will be validated in the oracle contract.
     * @param _req The initialized HashBridgeOracle Request
     * @return The bytes payload for the `transferAndCall` method
     */
    function encodeRequest(HashBridgeOracle.Request memory _req)
        private
        view
        returns (bytes memory)
    {
        return
            abi.encodeWithSelector(
                oracle.oracleRequest.selector,
                SENDER_OVERRIDE, // Sender value - overridden by onTokenTransfer by the requesting contract's address
                AMOUNT_OVERRIDE, // Amount value - overridden by onTokenTransfer by the actual amount of HBO sent
                _req.id,
                _req.callbackAddress,
                _req.callbackFunctionId,
                _req.nonce,
                ARGS_VERSION,
                _req.buf.buf
            );
    }

    /**
     * @notice Ensures that the fulfillment is valid for this contract
     * @dev Use if the contract developer prefers methods instead of modifiers for validation
     * @param _requestId The request ID for fulfillment
     */
    function validateHashBridgeOracleCallback(bytes32 _requestId)
        internal
        recordHashBridgeOracleFulfillment(_requestId)
    // solhint-disable-next-line no-empty-blocks
    {

    }

    /**
     * @dev Reverts if the sender is not the oracle of the request.
     * Emits HashBridgeOracleFulfilled event.
     * @param _requestId The request ID for fulfillment
     */
    modifier recordHashBridgeOracleFulfillment(bytes32 _requestId) {
        require(
            msg.sender == pendingRequests[_requestId],
            "Source must be the oracle of the request"
        );
        delete pendingRequests[_requestId];
        emit HashBridgeOracleFulfilled(_requestId);
        _;
    }

    /**
     * @dev Reverts if the request is already pending
     * @param _requestId The request ID for fulfillment
     */
    modifier notPendingRequest(bytes32 _requestId) {
        require(
            pendingRequests[_requestId] == address(0),
            "Request is already pending"
        );
        _;
    }
}
