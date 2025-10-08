// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "forge-std/Test.sol";
import "../src/LandSaleAgreement.sol";

contract LandSaleAgreementTest is Test {
    LandSaleAgreement public landSale;

    
    address public firm = address(0xF1);
    address public courthouse = address(0xC0);
    address public seller = address(0x03);
    address public buyer = address(0xB2);
    address public verifier = address(0x05);

    function setUp() public {
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

       
        vm.prank(firm);
        landSale.registerProperty(propertyId, seller, "ipfs://title-docs-1");

       
        vm.prank(seller);
        landSale.listPropertyForSale(propertyId, price);

       
        vm.deal(buyer, 100 ether);
        vm.prank(buyer);
        landSale.payHalf{value: half}(saleId);

      
        vm.prank(buyer);
        landSale.assignVerifier(saleId, verifier);

        
        vm.prank(verifier);
        landSale.verifierDecision(saleId, true);

        
        vm.deal(seller, 0);
        uint256 sellerBefore = seller.balance;

        
        vm.prank(buyer);
        landSale.payRemaining{value: price - half}(saleId);

       
        uint256 sellerAfter = seller.balance;
        assertEq(sellerAfter - sellerBefore, price, "Seller did not receive full price");

       
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

        
        vm.prank(firm);
        landSale.registerProperty(propertyId, seller, "ipfs://title-docs-10");
        vm.prank(seller);
        landSale.listPropertyForSale(propertyId, price);

        
        vm.deal(buyer, 10 ether);
        vm.prank(buyer);
        landSale.payHalf{value: half}(saleId);

      
        vm.prank(buyer);
        landSale.raiseDispute(saleId);

        
        vm.deal(seller, 0);
        uint256 sellerBefore = seller.balance;

       
        vm.prank(courthouse);
        landSale.resolveDispute(saleId, payable(seller), half);

        uint256 sellerAfter = seller.balance;
        assertGt(sellerAfter, sellerBefore, "Seller should receive held half after dispute resolution");

       
        (
            , , , , , , , , , , bool completed, bool disputeRaised
        ) = landSale.sales(saleId);
       
        assertFalse(disputeRaised, "Dispute flag should be cleared after resolution");
    }

    function testDisputeResolvedToBuyerByCourt() public {
        uint256 propertyId = 11;
        uint256 price = 6 ether;
        uint256 half = price / 2;
        uint256 saleId = 1;

      
        vm.prank(firm);
        landSale.registerProperty(propertyId, seller, "ipfs://title-docs-11");
        vm.prank(seller);
        landSale.listPropertyForSale(propertyId, price);

     
        vm.deal(buyer, 10 ether);
        vm.prank(buyer);
        landSale.payHalf{value: half}(saleId);

        
        vm.prank(buyer);
        landSale.raiseDispute(saleId);

        uint256 buyerBefore = buyer.balance;

        vm.prank(courthouse);
        landSale.resolveDispute(saleId, payable(buyer), half);

        uint256 buyerAfter = buyer.balance;
        assertGt(buyerAfter, buyerBefore, "Buyer should be refunded the held half by court");

       
        (
            , , , , , , , , , , bool completed, bool disputeRaised
        ) = landSale.sales(saleId);
        assertFalse(disputeRaised, "Dispute flag should be cleared after resolution");
    }
}
