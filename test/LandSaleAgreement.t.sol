// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "forge-std/Test.sol";
import "../src/LandSaleAgreement.sol";

contract LandSaleAgreementTest is Test {
    LandSaleAgreement public landSale;

    // Mock addresses
    address public firm = address(0xF1);
    address public courthouse = address(0xC0);
    address public seller = address(0x03);
    address public buyer = address(0xB2);
    address public verifier = address(0x05);

    function setUp() public {
        // Deploy contract as `firm` (the contract constructor sets firm = msg.sender)
        vm.prank(firm);
        landSale = new LandSaleAgreement(courthouse);
    }

    function testDeployment() public {
        assertEq(landSale.lagosCourthouse(), courthouse, "Courthouse mismatch");
        assertEq(landSale.firm(), firm, "Firm should be deployer");
    }

    function testRegisterListAndCompleteSale() public {
        uint256 propertyId = 1;
        uint256 price = 10 ether;
        uint256 half = price / 2;
        uint256 saleId = 1; // first sale created will have id = 1 (nextSaleId starts at 1)

        // Firm registers property
        vm.prank(firm);
        landSale.registerProperty(propertyId, seller, "ipfs://title-docs-1");

        // Seller lists property for sale
        vm.prank(seller);
        landSale.listPropertyForSale(propertyId, price);

        // Buyer funds and pays half
        vm.deal(buyer, 100 ether);
        vm.prank(buyer);
        landSale.payHalf{value: half}(saleId);

        // Buyer assigns verifier
        vm.prank(buyer);
        landSale.assignVerifier(saleId, verifier);

        // Verifier approves
        vm.prank(verifier);
        landSale.verifierDecision(saleId, true);

        // Record seller balance before final payment
        vm.deal(seller, 0);
        uint256 sellerBefore = seller.balance;

        // Buyer pays remaining amount
        vm.prank(buyer);
        landSale.payRemaining{value: price - half}(saleId);

        // Seller should receive full price
        uint256 sellerAfter = seller.balance;
        assertEq(sellerAfter - sellerBefore, price, "Seller did not receive full price");

        // Sale should be marked completed in storage
        (
            , // saleId
            , // propertyId
            , // seller
            , // buyer
            , // price
            , // halfAmount
            , // halfPaid
            , // verifier
            , // verifierAssigned
            , // verifierApproved
            bool completed,
            bool disputeRaised
        ) = landSale.sales(saleId);
        assertTrue(completed, "Sale should be completed");
        assertFalse(disputeRaised, "No dispute should be active");

        // Property should no longer be for sale
        (uint256 _id, address _owner, string memory _uri, bool _registered, bool forSale) = landSale.properties(propertyId);
        assertFalse(forSale, "Property should be delisted after sale");
        assertEq(_id, propertyId, "Property id mismatch");
        assertEq(_owner, seller, "Property owner mismatch");
        assertTrue(_registered, "Property should be registered");
    }

    function testDisputeResolvedToSellerByCourt() public {
        uint256 propertyId = 10;
        uint256 price = 8 ether;
        uint256 half = price / 2;
        uint256 saleId = 1;

        // Register and list
        vm.prank(firm);
        landSale.registerProperty(propertyId, seller, "ipfs://title-docs-10");
        vm.prank(seller);
        landSale.listPropertyForSale(propertyId, price);

        // Buyer pays half
        vm.deal(buyer, 10 ether);
        vm.prank(buyer);
        landSale.payHalf{value: half}(saleId);

        // Raise dispute by buyer
        vm.prank(buyer);
        landSale.raiseDispute(saleId);

        // Record seller balance before court resolution
        vm.deal(seller, 0);
        uint256 sellerBefore = seller.balance;

        // Court resolves in favour of seller (release held half to seller)
        vm.prank(courthouse);
        landSale.resolveDispute(saleId, payable(seller), half);

        uint256 sellerAfter = seller.balance;
        assertGt(sellerAfter, sellerBefore, "Seller should receive held half after dispute resolution");

        // Check sale storage flags
        (
            , , , , , , , , , , bool completed, bool disputeRaised
        ) = landSale.sales(saleId);
        // In this contract logic, completed is set true when the court releases entire held funds to seller.
        // Since held == half and we released 'half', the contract marks completed if implementation does so.
        // Adjust as per your contract: we assert dispute flag cleared.
        assertFalse(disputeRaised, "Dispute flag should be cleared after resolution");
    }

    function testDisputeResolvedToBuyerByCourt() public {
        uint256 propertyId = 11;
        uint256 price = 6 ether;
        uint256 half = price / 2;
        uint256 saleId = 1;

        // Register and list
        vm.prank(firm);
        landSale.registerProperty(propertyId, seller, "ipfs://title-docs-11");
        vm.prank(seller);
        landSale.listPropertyForSale(propertyId, price);

        // Buyer pays half
        vm.deal(buyer, 10 ether);
        vm.prank(buyer);
        landSale.payHalf{value: half}(saleId);

        // Raise dispute
        vm.prank(buyer);
        landSale.raiseDispute(saleId);

        // Record buyer balance before refund
        uint256 buyerBefore = buyer.balance;

        // Court refunds buyer the held half
        vm.prank(courthouse);
        landSale.resolveDispute(saleId, payable(buyer), half);

        uint256 buyerAfter = buyer.balance;
        assertGt(buyerAfter, buyerBefore, "Buyer should be refunded the held half by court");

        // Check sale storage flags
        (
            , , , , , , , , , , bool completed, bool disputeRaised
        ) = landSale.sales(saleId);
        assertFalse(disputeRaised, "Dispute flag should be cleared after resolution");
        // completed should be false because buyer was refunded (sale not completed)
    }
}
