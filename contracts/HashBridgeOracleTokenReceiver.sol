// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

abstract contract HashBridgeOracleTokenReceiver {
    bytes4 private constant ORACLE_REQUEST_SELECTOR = 0x40429946;
    uint256 private constant SELECTOR_LENGTH = 4;
    uint256 private constant EXPECTED_REQUEST_WORDS = 2;
    uint256 private constant MINIMUM_REQUEST_LENGTH =
        SELECTOR_LENGTH + (32 * EXPECTED_REQUEST_WORDS);

    /**
     * @notice Called when HBO is sent to the contract via `transferAndCall`
     * @dev The data payload's first 2 words will be overwritten by the `_sender` and `_amount`
     * values to ensure correctness. Calls oracleRequest.
     * @param _sender Address of the sender
     * @param _amount Amount of HBO sent (specified in wei)
     * @param _data Payload of the transaction
     */
    function onTokenTransfer(
        address _sender,
        uint256 _amount,
        bytes memory _data
    ) public onlyHBO validRequestLength(_data) permittedFunctionsForHBO(_data) {
        assembly {
            // solhint-disable-next-line avoid-low-level-calls
            mstore(add(_data, 36), _sender) // ensure correct sender is passed
            // solhint-disable-next-line avoid-low-level-calls
            mstore(add(_data, 68), _amount) // ensure correct amount is passed
        }
        // solhint-disable-next-line avoid-low-level-calls
        (bool success, ) = address(this).delegatecall(_data); // calls oracleRequest
        require(success, "Unable to create request");
    }

    function getHashBridgeOracleToken() public view virtual returns (address);

    /**
     * @dev Reverts if not sent from the HBO token
     */
    modifier onlyHBO() {
        require(msg.sender == getHashBridgeOracleToken(), "Must use HBO token");
        _;
    }

    /**
     * @dev Reverts if the given data does not begin with the `oracleRequest` function selector
     * @param _data The data payload of the request
     */
    modifier permittedFunctionsForHBO(bytes memory _data) {
        bytes4 funcSelector;
        assembly {
            // solhint-disable-next-line avoid-low-level-calls
            funcSelector := mload(add(_data, 32))
        }
        require(
            funcSelector == ORACLE_REQUEST_SELECTOR,
            "Must use whitelisted functions"
        );
        _;
    }

    /**
     * @dev Reverts if the given payload is less than needed to create a request
     * @param _data The request payload
     */
    modifier validRequestLength(bytes memory _data) {
        require(
            _data.length >= MINIMUM_REQUEST_LENGTH,
            "Invalid request length"
        );
        _;
    }
}
