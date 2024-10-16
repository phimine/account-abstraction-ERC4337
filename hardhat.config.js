require("@nomicfoundation/hardhat-toolbox");

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
    solidity: {
        version: "0.8.24",
        optimizer: {
            enabled: true,
            runs: 2000,
        },
    },
};
