// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract SnafuVotes {   
    IERC20 constant snafuToken = IERC20(0x27B9C2Bd4BaEa18ABdF49169054c1C1c12af9862);
    IERC20 constant snafuFarm = IERC20(0x8dDc7167e9F838f2e32FaBA229A53d4a48D0aa8d);
    IERC20 constant snafuLPFarm = IERC20(0x88CfEea7BE8A7695A3012276e8C68bf303Afe49a);
    address constant wxdaiPairAddress = 0xD6C8Ad00302CA94952E7746D956e8B45B0Ea90E3;
    IERC20 constant snafuWxdaiPair = IERC20(wxdaiPairAddress);

    function balanceOf(address account) public view returns (uint256){
        //SNAFU balance
        uint256 balance = snafuToken.balanceOf(account);
        //SNAFU staked in Unifty farm
        balance += snafuFarm.balanceOf(account);
        //SNAFU-WXDAI LP staked in Unifty Farm
        uint256 lps = snafuLPFarm.balanceOf(account);
        //SNAFU-WXDAI LP balance
        lps += snafuWxdaiPair.balanceOf(account);

        //converts Lps to Snafu
        balance += wxdaiLpToSnafu(lps);

        return balance;
    }

    function wxdaiLpToSnafu(uint256 lpAmount) public view returns(uint256){
        uint256 snafuInPool = snafuToken.balanceOf(wxdaiPairAddress);
        uint256 totalLp = snafuWxdaiPair.totalSupply();
        return (lpAmount * snafuInPool) / totalLp;
    }

}