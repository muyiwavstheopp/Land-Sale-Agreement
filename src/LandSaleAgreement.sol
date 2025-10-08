// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

contract LandSaleAgreement {
    address public firm; // Aderemi Chambers
    address public lagosCourthouse; // Lagos State MultiDoor Courthouse official address

    constructor(address _lagosCourthouse) {
        require(_lagosCourthouse != address(0), "Invalid courthouse address");
        firm = msg.sender; // deployer is the firm
        lagosCourthouse = _lagosCourthouse;
    }

    modifier onlyFirm() {
        require(msg.sender == firm, "Only firm can call");
        _;
    }

    modifier onlyCourt() {
        require(msg.sender == lagosCourthouse, "Only Lagos MultiDoor Courthouse can call");
        _;
    }

    struct Property {
        uint id;
        address owner;
        string metadataURI;
        bool registered;
        bool forSale;
    }

    mapping(uint => Property) public properties;

    event PropertyRegistered(uint indexed propertyId, address indexed owner, string metadataURI);
    event PropertyListedForSale(uint indexed propertyId, uint indexed saleId, uint price);
    event PropertyDelisted(uint indexed propertyId);

    struct Sale {
        uint saleId;
        uint propertyId;
        address seller;
        address buyer;
        uint price;
        uint halfAmount;
        bool halfPaid;
        address verifier;
        bool verifierAssigned;
        bool verifierApproved;
        bool completed;
        bool disputeRaised;
    }

    uint private nextSaleId = 1;
    mapping(uint => Sale) public sales;

    event SaleCreated(uint indexed saleId, uint indexed propertyId, address indexed seller, uint price);
    event HalfPaid(uint indexed saleId, address indexed buyer, uint amount);
    event VerifierAssigned(uint indexed saleId, address indexed verifier);
    event VerifierDecision(uint indexed saleId, address indexed verifier, bool approved);
    event RemainingPaidAndCompleted(uint indexed saleId, address indexed buyer, uint amount);
    event DisputeRaised(uint indexed saleId, address indexed who);
    event DisputeResolved(uint indexed saleId, address indexed to, uint amountOut);

 

    function registerProperty(uint _propertyId, address _owner, string calldata _metadataURI) external onlyFirm {
        Property storage p = properties[_propertyId];
        require(!p.registered, "Property already registered");
        p.id = _propertyId;
        p.owner = _owner;
        p.metadataURI = _metadataURI;
        p.registered = true;
        p.forSale = false;
        emit PropertyRegistered(_propertyId, _owner, _metadataURI);
    }

    function listPropertyForSale(uint _propertyId, uint _price) external {
        Property storage p = properties[_propertyId];
        require(p.registered, "Property not registered by firm");
        require(msg.sender == p.owner, "Only property owner can list");
        require(!p.forSale, "Already for sale");
        require(_price > 0, "Price must be > 0");

        p.forSale = true;
        uint sid = nextSaleId++;
        Sale storage s = sales[sid];
        s.saleId = sid;
        s.propertyId = _propertyId;
        s.seller = msg.sender;
        s.price = _price;
        s.halfAmount = _price / 2;
        emit SaleCreated(sid, _propertyId, msg.sender, _price);
        emit PropertyListedForSale(_propertyId, sid, _price);
    }

    function delistProperty(uint _propertyId) external {
        Property storage p = properties[_propertyId];
        require(p.registered, "Property not registered");
        require(msg.sender == p.owner, "Only owner can delist");
        p.forSale = false;
        emit PropertyDelisted(_propertyId);
    }

  
    function payHalf(uint _saleId) external payable {
        Sale storage s = sales[_saleId];
        require(s.saleId != 0, "Sale not found");
        require(!s.completed, "Sale already completed");
        require(!s.disputeRaised, "Sale in dispute");
        require(!s.halfPaid, "Half already paid");
        require(msg.value == s.halfAmount, "Must send exact half amount");
        s.buyer = msg.sender;
        s.halfPaid = true;
        emit HalfPaid(_saleId, msg.sender, msg.value);
    }

    function assignVerifier(uint _saleId, address _verifier) external {
        Sale storage s = sales[_saleId];
        require(s.saleId != 0, "Sale not found");
        require(s.halfPaid, "Half payment required before assigning verifier");
        require(msg.sender == s.buyer, "Only the buyer may assign verifier");
        require(!s.verifierAssigned, "Verifier already assigned");
        require(_verifier != address(0), "Invalid verifier address");
        s.verifier = _verifier;
        s.verifierAssigned = true;
        emit VerifierAssigned(_saleId, _verifier);
    }

    function verifierDecision(uint _saleId, bool _approved) external {
        Sale storage s = sales[_saleId];
        require(s.saleId != 0, "Sale not found");
        require(s.verifierAssigned, "No verifier assigned");
        require(msg.sender == s.verifier, "Only assigned verifier can call");
        require(!s.disputeRaised, "Sale in dispute");
        require(!s.completed, "Sale already completed");
        s.verifierApproved = _approved;
        emit VerifierDecision(_saleId, msg.sender, _approved);
    }

    function payRemaining(uint _saleId) external payable {
        Sale storage s = sales[_saleId];
        require(s.saleId != 0, "Sale not found");
        require(s.halfPaid, "Half payment not made");
        require(s.verifierAssigned, "Verifier not assigned");
        require(s.verifierApproved, "Verifier has not approved the property");
        require(!s.completed, "Sale already completed");
        require(!s.disputeRaised, "Sale in dispute");
        require(msg.sender == s.buyer, "Only buyer can pay remaining");
        uint remaining = s.price - s.halfAmount;
        require(msg.value == remaining, "Must send exact remaining amount");
        s.completed = true;
        (bool sent, ) = payable(s.seller).call{value: s.price}("");
        require(sent, "Transfer to seller failed");
        Property storage p = properties[s.propertyId];
        p.forSale = false;
        emit RemainingPaidAndCompleted(_saleId, msg.sender, msg.value);
    }

        function raiseDispute(uint _saleId) external {
        Sale storage s = sales[_saleId];
        require(s.saleId != 0, "Sale not found");
        require(msg.sender == s.buyer || msg.sender == s.seller, "Only buyer or seller can raise dispute");
        require(!s.disputeRaised, "Dispute already raised");
        s.disputeRaised = true;
        emit DisputeRaised(_saleId, msg.sender);
    }

    function resolveDispute(uint _saleId, address payable _to, uint _amountOut) external onlyCourt {
        Sale storage s = sales[_saleId];
        require(s.saleId != 0, "Sale not found");
        require(s.disputeRaised, "No dispute to resolve");
        uint held = s.halfPaid && !s.completed ? s.halfAmount : 0;
        require(_amountOut <= held, "Amount exceeds escrow");
        s.disputeRaised = false;
        if (_amountOut > 0) {
            (bool sent, ) = _to.call{value: _amountOut}("");
            require(sent, "Transfer failed");
        }
        if (_to == s.seller && _amountOut == held) {
            s.completed = true;
        }
        emit DisputeResolved(_saleId, _to, _amountOut);
    }

    receive() external payable {
        revert("Direct deposits not accepted");
    }

    fallback() external payable {
        revert("Fallback not allowed");
    }
}
