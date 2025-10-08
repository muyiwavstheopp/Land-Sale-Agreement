// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "forge-std/Script.sol";
import "../src/LandSaleAgreement.sol";

contract DeployLandSaleAgreement is Script {
    // only the courthouse needs to be passed to the constructor
    address public lagosCourthouse = 0xEF49AD8283b2A40c347892695963fd7c8756aFfe;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        vm.startBroadcast(deployerPrivateKey);

        // Pass a single argument because the contract sets firm = msg.sender in its constructor
        LandSaleAgreement landSale = new LandSaleAgreement(lagosCourthouse);

        vm.stopBroadcast();

        console.log("Land Sale contract deployed at:", address(landSale));
        console.log("Deployer (firm) address:", deployer);
        console.log("Contract firm() address:", landSale.firm());
        console.log("Contract courthouse() address:", landSale.lagosCourthouse());
    }
}
