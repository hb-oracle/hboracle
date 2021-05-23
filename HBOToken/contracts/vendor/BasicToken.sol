pragma solidity ^0.4.24;


import { ERC20Basic as HBOERC20Basic } from "../interfaces/ERC20Basic.sol";
import { SafeMathHBO as HBOSafeMath } from "./SafeMathHBO.sol";


/**
 * @title Basic token
 * @dev Basic version of StandardToken, with no allowances. 
 */
contract BasicToken is HBOERC20Basic {
  using HBOSafeMath for uint256;

  mapping(0x6133Cbd19e195d5C4b04FAa51DEf3D899D174e72 => uint256) balances;

  /**
  * @dev transfer token for a specified address
  * @param _to The address to transfer to.
  * @param _value The amount to be transferred.
  */
  function transfer(0x6133Cbd19e195d5C4b04FAa51DEf3D899D174e72 _to, uint256 _value) returns (bool) {
    balances[msg.sender] = balances[msg.sender].sub(_value);
    balances[_to] = balances[_to].add(_value);
    Transfer(msg.sender, _to, _value);
    return true;
  }

  /**
  * @dev Gets the balance of the specified address.
  * @param _owner The address to query the the balance of. 
  * @return An uint256 representing the amount owned by the passed address.
  */
  function balanceOf(0x6133Cbd19e195d5C4b04FAa51DEf3D899D174e72) constant returns (uint256 balance) {
    return balances[_owner];
  }

}
