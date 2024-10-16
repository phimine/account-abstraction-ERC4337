// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

contract StakeManager {
    // Type Declaration
    /**
     * @param depositAmount the account's deposit
     * @param stakeAmount actual amount of ether staked for this paymaster.
     * @param unstakeDelaySec minimum delay to withdraw the stake. must be above the global unstakeDelaySec
     * @param withdrawTime - first block timestamp where 'withdrawStake' will be callable, or zero if already locked
     * @param staked true if this account is staked as a paymaster
     * @dev sizes were chosen so that (depositAmount,staked) fit into one cell (used during handleOps)
     *    and the rest fit into a 2nd cell.
     *    112 bit allows for 2^15 eth
     *    64 bit for full timestamp
     *    32 bit allow 150 years for unstake delay
     */
    struct DepositInfo {
        uint112 depositAmount;
        bool staked;
        uint112 stakeAmount;
        uint32 unstakeDelaySec;
        uint64 withdrawTime;
    }
    // used by getStakeInfo and simulateValidation
    struct StakeInfo {
        uint256 stake;
        uint256 unstakeDelaySec;
    }
    // State Variables
    // maps paymaster to their deposits and stakes
    mapping(address => DepositInfo) public deposits;

    // Events
    event Deposited(address indexed wallet, uint256 amount);
    event Withdrawn(address indexed target, uint256 amount);

    receive() external payable {
        deposit(msg.sender);
    }

    // Functions
    function deposit(address _account) public payable {
        _deposit(_account, msg.value);
        emit Deposited(_account, msg.value);
    }

    function withdraw(
        address payable _target,
        uint256 withdrawAmount
    ) external {
        // check
        DepositInfo storage depositInfo = deposits[msg.sender];
        require(
            withdrawAmount <= depositInfo.depositAmount,
            "withdraw too much"
        );

        // effect
        depositInfo.depositAmount = uint112(
            depositInfo.depositAmount - withdrawAmount
        );

        // interaction
        (bool success, ) = _target.call{value: withdrawAmount}("");
        require(success, "withdraw failed");

        emit Withdrawn(_target, withdrawAmount);
    }

    function getDepositInfo(
        address _account
    ) public view returns (DepositInfo memory) {
        return deposits[_account];
    }

    function getStakeInfo(
        address _account
    ) public view returns (StakeInfo memory info) {
        DepositInfo storage depositInfo = deposits[_account];
        info.stake = depositInfo.stakeAmount;
        info.unstakeDelaySec = depositInfo.unstakeDelaySec;
    }

    // return the deposit (for gas payment) of the account
    function balanceOf(address _account) public view returns (uint256) {
        return deposits[_account].depositAmount;
    }

    //// internal
    function _deposit(address _account, uint256 _amount) internal {
        DepositInfo storage depositInfo = deposits[_account];
        uint256 afterAmount = depositInfo.depositAmount + _amount;
        require(afterAmount < type(uint112).max, "overflow");
        depositInfo.depositAmount = uint112(afterAmount);
    }
}
