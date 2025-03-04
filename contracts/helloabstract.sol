// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./ERC721C.sol";


contract HelloAbstract is ERC721C, Ownable(msg.sender), ReentrancyGuard {
    using Strings for uint256;
    uint256 public constant MAX_SUPPLY = 5555;
    uint256 public constant AIRDROP_SUPPLY = 1111;
    uint256 public publicMintPrice;
    uint256 public allowlist01Price;
    uint256 public maxPerWallet = 2;
    bool public publicMintActive;
    bool public allowlist01Active;
    bool public allowlist02Active;
    uint256 public totalAllowlist02;
    mapping(address => bool) public allowlist01;
    mapping(address => bool) public allowlist02;
    mapping(address => uint256) public publicMintCount;
    mapping(address => uint256) public allowlist01MintCount;
    mapping(address => uint256) public allowlist02MintCount;
    address public burnClaimContract;
    mapping(uint256 => bool) public tokenBurned;
    uint96 private royaltyFee;
    address private royaltyRecipient;
    string private baseURI;
   address[] public allowlist01Addresses;
    address[] public allowlist02Addresses;


    constructor(
        string memory _name,
        string memory _symbol,
        uint256 _publicMintPrice,
        uint256 _allowlist01Price,
        uint96 _royaltyFee,
        address _royaltyRecipient
    ) ERC721C(_name, _symbol) {
        publicMintPrice = _publicMintPrice;
        allowlist01Price = _allowlist01Price;
        royaltyFee = _royaltyFee;
        royaltyRecipient = _royaltyRecipient;
    }

 function addToAllowlist01(address[] calldata addresses) external onlyOwner {
    for (uint256 i = 0; i < addresses.length; i++) {
        if (!allowlist01[addresses[i]]) {
            allowlist01[addresses[i]] = true;
         allowlist01Addresses.push(addresses[i]);
        }
    }
}

function getAllowlist01Addresses() external view returns (address[] memory) {
    return allowlist01Addresses;
}

 function addToAllowlist02(address[] calldata addresses) external onlyOwner {
    for (uint256 i = 0; i < addresses.length; i++) {
        if (!allowlist02[addresses[i]]) {  // Only increment if not already in list
            allowlist02[addresses[i]] = true;
            allowlist02Addresses.push(addresses[i]); // Store address
        }
    }
}

function getAllowlist02Addresses() external view returns (address[] memory) {
    return allowlist02Addresses;
}

    function publicMint(uint256 quantity) external payable nonReentrant {
        require(publicMintActive, "Public mint not active");
        require(
            msg.value >= publicMintPrice * quantity,
            "Insufficient payment"
        );
        require(
            publicMintCount[msg.sender] + quantity <= maxPerWallet,
            "Exceeds wallet limit"
        );
        require(totalSupply() + quantity <= MAX_SUPPLY, "Exceeds max supply");

        publicMintCount[msg.sender] += quantity;
        _mintLoop(msg.sender, quantity);
    }

    function allowlist01Mint(uint256 quantity) external payable nonReentrant {
        require(allowlist01Active, "Allowlist 01 mint not active");
        require(allowlist01[msg.sender], "Not on allowlist");
        require(
            msg.value >= allowlist01Price * quantity,
            "Insufficient payment"
        );
        require(
            allowlist01MintCount[msg.sender] + quantity <= maxPerWallet,
            "Exceeds wallet limit"
        );
        require(totalSupply() + quantity <= MAX_SUPPLY, "Exceeds max supply");

        allowlist01MintCount[msg.sender] += quantity;
        _mintLoop(msg.sender, quantity);
    }

    function allowlist02Mint(uint256 quantity) external nonReentrant {
        require(allowlist02Active, "Allowlist 02 mint not active");
        require(allowlist02[msg.sender], "Not on allowlist");
        require(
            allowlist02MintCount[msg.sender] + quantity <= maxPerWallet,
            "Exceeds wallet limit"
        );
        require(totalSupply() + quantity <= MAX_SUPPLY, "Exceeds max supply");

        allowlist02MintCount[msg.sender] += quantity;
        _mintLoop(msg.sender, quantity);
    }

    function airdrop(
        address[] calldata recipients,
        uint256[] calldata quantities
    ) external onlyOwner {
        require(
            recipients.length == quantities.length,
            "Array length mismatch"
        );
        uint256 totalQuantity = 0;
        for (uint256 i = 0; i < quantities.length; i++) {
            totalQuantity += quantities[i];
        }
        require(totalQuantity <= AIRDROP_SUPPLY, "Exceeds airdrop supply");

        for (uint256 i = 0; i < recipients.length; i++) {
            _mintLoop(recipients[i], quantities[i]);
        }
    }

    function setBurnClaimContract(address _burnClaimContract)
        external
        onlyOwner
    {
        burnClaimContract = _burnClaimContract;
    }

    function burnAndClaim(uint256 tokenId) external {
        require(ownerOf(tokenId) == msg.sender, "Not token owner");
        require(!tokenBurned[tokenId], "Token already burned");
        require(burnClaimContract != address(0), "Claim contract not set");
        tokenBurned[tokenId] = true;
        _burn(tokenId);
        IBurnClaim(burnClaimContract).claimNewToken(msg.sender, tokenId);
    }

    function setMintPhases(
        bool _public,
        bool _al01,
        bool _al02
    ) external onlyOwner {
        publicMintActive = _public;
        allowlist01Active = _al01;
        allowlist02Active = _al02;
    }

    function setPricing(uint256 _publicPrice, uint256 _al01Price)
        external
        onlyOwner
    {
        publicMintPrice = _publicPrice;
        allowlist01Price = _al01Price;
    }

    function setRoyaltyInfo(address _recipient, uint96 _fee)
        external
        onlyOwner
    {
        royaltyRecipient = _recipient;
        royaltyFee = _fee;
    }

    function setBaseURI(string calldata _newBaseURI) external onlyOwner {
        baseURI = _newBaseURI;
    }

    function totalSupply() public view returns (uint256) {
        return _totalSupply();
    }

    function tokenURI(uint256 tokenId)
        public
        view
        virtual
        override
        returns (string memory)
    {
        require(_exists(tokenId), "Token does not exist");
        return string(abi.encodePacked(baseURI, tokenId.toString()));
    }

    function royaltyInfo(uint256 tokenId, uint256 salePrice)
        external
        view
        returns (address, uint256)
    {
        require(_exists(tokenId), "Token does not exist");
        return (royaltyRecipient, (salePrice * royaltyFee) / 10000);
    }


    function _mintLoop(address recipient, uint256 quantity) internal {
        for (uint256 i = 0; i < quantity; i++) {
            _safeMint(recipient, totalSupply() + 1);
        }
    }

    function withdraw() external onlyOwner {
        (bool success, ) = msg.sender.call{value: address(this).balance}("");
        require(success, "Transfer failed");
    }

    function getActivePhase() public view returns (string memory) {
        if (publicMintActive) return "publicMintActive";
        if (allowlist01Active) return "allowlist01Active";
        if (allowlist02Active) return "allowlist02Active";
        return "none";
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override
        returns (bool)
    {
        return
            interfaceId == 0x2a55205a || super.supportsInterface(interfaceId);
    }
}

interface IBurnClaim {
    function claimNewToken(address claimer, uint256 burnedTokenId) external;
}
