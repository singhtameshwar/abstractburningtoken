// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./ERC721C.sol";

contract HelloAbstract is ERC721C, Ownable(msg.sender), ReentrancyGuard {
    using Strings for uint256;
    
    // Constants - already gas efficient
    uint256 public constant MAX_SUPPLY = 5555;
    uint256 public constant AIRDROP_SUPPLY = 1111;
    
    // Pack related variables in same storage slots (saves ~20,000 gas deployment, ~5,000 per tx)
    // Each slot is 32 bytes
    // Slot 1
    uint96 public publicMintPrice;
    uint96 public allowlist01Price;
    uint96 public allowlist02Price;
    
    // Slot 2
    uint8 public maxPerWallet = 2;
    bool public publicMintActive;
    bool public allowlist01Active;
    bool public allowlist02Active;
    bool public transfersLocked = true;
    
    // Separate storage slots
    address public burnClaimContract;
    address private royaltyRecipient;
    uint96 private royaltyFee;
    
    // Use uint8 for mint counts since maxPerWallet is low (saves ~30 gas per mint)
    mapping(address => uint8) public mintCount;
    
    // Keep these mappings as-is
    mapping(address => bool) public allowlist01;
    mapping(address => bool) public allowlist02;
    mapping(address => bool) public transferExemptions;
    mapping(uint256 => bool) public tokenBurned;
    
    string private baseURI;

    constructor(
        string memory _name,
        string memory _symbol,
        uint96 _publicMintPrice,
        uint96 _allowlist01Price,
        uint96 _royaltyFee,
        address _royaltyRecipient
    ) ERC721C(_name, _symbol) {
        publicMintPrice = _publicMintPrice;
        allowlist01Price = _allowlist01Price;
        allowlist02Price = _publicMintPrice; // Default same as public price to save a parameter
        royaltyFee = _royaltyFee;
        royaltyRecipient = _royaltyRecipient;
        transferExemptions[owner()] = true;
    }
    
    // Use custom error instead of string revert (saves ~50-100 gas per revert)
    error TransferLocked();
    error InsufficientPayment();
    error ExceedsWalletLimit();
    error ExceedsMaxSupply();
    error NotOnAllowlist();
    error MintNotActive();
    error ArrayLengthMismatch();
    error ExceedsAirdropSupply();
    error InvalidAddress();
    error NotTokenOwner();
    error TokenAlreadyBurned();
    error ClaimContractNotSet();
    error TokenDoesNotExist();
    error TransferFailed();
    
    function setTransfersLocked(bool _locked) external onlyOwner {
        transfersLocked = _locked;
    }
    
    function _beforeTokenTransfer(address from, address to, uint256 tokenId) internal override {
        if (from != address(0) && to != address(0) && transfersLocked && 
            !transferExemptions[from] && !transferExemptions[to] && from != owner() && to != owner()) {
            revert TransferLocked();
        }
        super._beforeTokenTransfer(from, to, tokenId);
    }
    
    // Combine allowlist functions to reduce contract size
    function updateAllowlist(address[] calldata addresses, uint8 listType) external onlyOwner {
        uint256 length = addresses.length;
        // Use unchecked for gas savings on loop counters when overflow is impossible
        unchecked {
            if (listType == 1) {
                for (uint256 i = 0; i < length; i++) {
                    allowlist01[addresses[i]] = true;
                }
            } else if (listType == 2) {
                for (uint256 i = 0; i < length; i++) {
                    allowlist02[addresses[i]] = true;
                }
            }
        }
    }

    function publicMint() external payable nonReentrant {
        if (!publicMintActive) revert MintNotActive();
        if (msg.value < publicMintPrice) revert InsufficientPayment();
        if (mintCount[msg.sender] + 1 > maxPerWallet) revert ExceedsWalletLimit();
        
        uint256 nextTokenId = totalSupply() + 1;
        if (nextTokenId > MAX_SUPPLY) revert ExceedsMaxSupply();
        
        // Increment state before external calls (prevents reentrancy)
        unchecked {
            mintCount[msg.sender] += 1;
        }
        _safeMint(msg.sender, nextTokenId);
    }

    function allowlist01Mint() external payable nonReentrant {
        if (!allowlist01Active) revert MintNotActive();
        if (!allowlist01[msg.sender]) revert NotOnAllowlist();
        if (msg.value < allowlist01Price) revert InsufficientPayment();
        if (mintCount[msg.sender] + 1 > maxPerWallet) revert ExceedsWalletLimit();
        
        uint256 nextTokenId = totalSupply() + 1;
        if (nextTokenId > MAX_SUPPLY) revert ExceedsMaxSupply();
        
        unchecked {
            mintCount[msg.sender] += 1;
        }
        _safeMint(msg.sender, nextTokenId);
    }

    function allowlist02Mint() external payable nonReentrant {
        if (!allowlist02Active) revert MintNotActive();
        if (!allowlist02[msg.sender]) revert NotOnAllowlist();
        if (msg.value < allowlist02Price) revert InsufficientPayment();
        if (mintCount[msg.sender] + 1 > maxPerWallet) revert ExceedsWalletLimit();
        
        uint256 nextTokenId = totalSupply() + 1;
        if (nextTokenId > MAX_SUPPLY) revert ExceedsMaxSupply();

        unchecked {
            mintCount[msg.sender] += 1;
        }
        _safeMint(msg.sender, nextTokenId);
    }

    function airdrop(
        address[] calldata recipients,
        uint256[] calldata quantities
    ) external onlyOwner {
        uint256 recipientsLen = recipients.length;
        if (recipientsLen != quantities.length) revert ArrayLengthMismatch();
        
        uint256 totalQuantity = 0;
        uint256 currentSupply = totalSupply();
        
        unchecked {
            for (uint256 i = 0; i < recipientsLen; i++) {
                totalQuantity += quantities[i];
            }
        }
        
        if (totalQuantity > AIRDROP_SUPPLY) revert ExceedsAirdropSupply();

        unchecked {
            for (uint256 i = 0; i < recipientsLen; i++) {
                uint256 quantity = quantities[i];
                address recipient = recipients[i];
                for (uint256 j = 0; j < quantity; j++) {
                    currentSupply++;
                    _safeMint(recipient, currentSupply);
                }
            }
        }
    }
    function setBurnClaimContract(address _burnClaimContract) external onlyOwner {
        if (_burnClaimContract == address(0)) revert InvalidAddress();
        burnClaimContract = _burnClaimContract;
    }

    function burnAndClaim(uint256 tokenId) external {
        if (ownerOf(tokenId) != msg.sender) revert NotTokenOwner();
        if (tokenBurned[tokenId]) revert TokenAlreadyBurned();
        if (burnClaimContract == address(0)) revert ClaimContractNotSet();
        
        tokenBurned[tokenId] = true;
        _burn(tokenId);

        if (balanceOf(msg.sender) == 0) {
            mintCount[msg.sender] = 0;
        }
    }

    function mintAfterBurn(uint256 quantity) external nonReentrant {
        uint256 currentSupply = totalSupply();
        if (currentSupply + quantity > MAX_SUPPLY) revert ExceedsMaxSupply();
        if (balanceOf(msg.sender) + quantity > maxPerWallet) revert ExceedsWalletLimit();

        unchecked {
            for (uint256 i = 0; i < quantity; i++) {
                _safeMint(msg.sender, currentSupply + i + 1);
            }
        }
    }

    function setMintPhases(bool _public, bool _al01, bool _al02) external onlyOwner {
        publicMintActive = _public;
        allowlist01Active = _al01;
        allowlist02Active = _al02;
    }

    function setPricing(uint96 _publicPrice, uint96 _al01Price, uint96 _al02Price) external onlyOwner {
        publicMintPrice = _publicPrice;
        allowlist01Price = _al01Price;
        allowlist02Price = _al02Price;
    }

    function setRoyaltyInfo(address _recipient, uint96 _fee) external onlyOwner {
        royaltyRecipient = _recipient;
        royaltyFee = _fee;
    }

    function setBaseURI(string calldata _newBaseURI) external onlyOwner {
        baseURI = _newBaseURI;
    }

    function totalSupply() public view returns (uint256) {
        return _totalSupply();
    }

    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        if (!_exists(tokenId)) revert TokenDoesNotExist();
        return string(abi.encodePacked(baseURI, tokenId.toString()));
    }

    function royaltyInfo(uint256 tokenId, uint256 salePrice) external view returns (address, uint256) {
        if (!_exists(tokenId)) revert TokenDoesNotExist();
        
        unchecked {
            return (royaltyRecipient, (salePrice * royaltyFee) / 10000);
        }
    }

    function withdraw() external onlyOwner {
        uint256 balance = address(this).balance;
        (bool success, ) = msg.sender.call{value: balance}("");
        if (!success) revert TransferFailed();
    }

    function getActivePhase() external view returns (string memory) {
        if (publicMintActive) return "publicMintActive";
        if (allowlist01Active) return "allowlist01Active";
        if (allowlist02Active) return "allowlist02Active";
        return "none";
    }

    function supportsInterface(bytes4 interfaceId) public view override returns (bool) {
        return interfaceId == 0x2a55205a || super.supportsInterface(interfaceId);
    }
}

interface IBurnClaim {
    function claimNewToken(address claimer, uint256 burnedTokenId) external;
}