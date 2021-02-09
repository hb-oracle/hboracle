pragma solidity ^0.6.0;

import "../HashBridgeOracleClient.sol";

contract APIConsumer is HashBridgeOracleClient {
  
    uint256 public volume;
    
    address private oracle;
    bytes32 private jobId;
    uint256 private fee;

    constructor(address _oracle, address _hbo) public {
        setHashBridgeOracleToken(_hbo);
        oracle = _oracle;
        jobId = "29fa9aa13bf1468788b7cc4a500a45b8";
        fee = 0.1 * 10 ** 18; // 0.1 HBO
    }
    
    /**
     * Create a HashBridge request to retrieve API response, find the target
     * data, then multiply by 1000000000000000000 (to remove decimal places from data).
     */
    function requestVolumeData() public returns (bytes32 requestId) 
    {
        HashBridgeOracle.Request memory request = buildHashBridgeOracleRequest(jobId, address(this), this.fulfill.selector);
        
        // Set the URL to perform the GET request on
        request.add("get", "https://min-api.cryptocompare.com/data/pricemultifull?fsyms=ETH&tsyms=USD");
        request.add("path", "RAW.ETH.USD.VOLUME24HOUR");

        // Multiply the result by 1000000000000000000 to remove decimals
        int timesAmount = 10**18;
        request.addInt("times", timesAmount);
        
        // Sends the request
        return sendHashBridgeOracleRequestTo(oracle, request, fee);
    }
    
    /**
     * Receive the response in the form of uint256
     */ 
    function fulfill(bytes32 _requestId, uint256 _volume) public recordHashBridgeOracleFulfillment(_requestId)
    {
        volume = _volume;
    }
}