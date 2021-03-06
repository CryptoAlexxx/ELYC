pragma solidity ^0.4.25;

import "./Ownable.sol";
import "./SafeMath.sol";
import "./ERC20.sol";

contract Memberships is Ownable {
    
    using SafeMath for uint256;
    
    
    uint256 private numOfMembers;
    uint256 private maxGramsPerMonth;
    uint256 private monthNo;
    ERC20 public ELYC;
    
    
    constructor() public {
        maxGramsPerMonth = 60;
        ELYC = ERC20(0xFD96F865707ec6e6C0d6AfCe1f6945162d510351); 
    }
    
    
    /**
     * MAPPINGS
     * */
    mapping (address => uint256) private memberIdByAddr;
    mapping (uint256 => address) private memberAddrById;
    mapping (address => bool) private addrIsMember;
    mapping (address => mapping (uint256 => uint256)) private memberPurchases;
    mapping (address => bool) private blacklist;
    
    
    /**
     * EVENTS
     * */
    event MaxGramsPerMonthChanged(uint256 from, uint256 to);
    event MemberBlacklisted(address indexed addr, uint256 indexed id, uint256 block);
    event MemberRemovedFromBlacklist(address indexed addr, uint256 indexed id, uint256 block);
    event NewMemberAdded(address indexed addr, uint256 indexed id, uint256 block);
    event CannabisPurchaseMade(address indexed by, uint256 milligrams, uint256 price, address indexed vendor, uint256 block);
    event PurchaseMade(address indexed by, uint256 _price, address indexed _vendor, uint256 block);
    event MonthNumberIncremented(uint256 block);
    
    
    /**
     * MODIFIERS
     * */
     modifier onlyMembers {
         require(
             addressHasMembership(msg.sender)
             && !memberIsBlacklisted(msg.sender)
             );
         _;
     }

    
    
    /**
     * GETTERS
     * */
     
    /**
     * @return The current number of months the contract has been running for
     * */
     function getMonthNo() public view returns(uint256) {
         return monthNo;
     }
     
    /**
     * @return The total amount of members 
     * */
    function getNumOfMembers() public view returns(uint256) {
        return numOfMembers;
    }
    
    
    /**
     * @return The maximum grams of cannabis each member can buy per month
     * */
    function getMaxGramsPerMonth() public view returns(uint256) {
        return maxGramsPerMonth;
    }
    
    
    /**
     * @param _addr The address which is being queried for membership
     * @return true if the address is a member, false otherwise
     * */
    function addressHasMembership(address _addr) public view returns(bool) {
        return addrIsMember[_addr];
    }
    
    
    /**
     * @param _addr The address associated with a member ID (if any).
     * @return The member ID if it exists, 0 otherwise
     * */
    function getMemberIdByAddr(address _addr) public view returns(uint256) {
        return memberIdByAddr[_addr];
    }
    
    
    /**
     * @param _id The ID associated with a member address (if any).
     * @return The member address if it exists, 0x00...00 otherwise.
     * */
    function getMemberAddrById(uint256 _id) public view returns(address) {
        return memberAddrById[_id];
    }
    
    
    /**
     * @param _addr The address which is being checked if it is on the blacklist
     * @return true if the address is on the blacklist, false otherwise
     * */
    function memberIsBlacklisted(address _addr) public view returns(bool) {
        return blacklist[_addr];
    }
    
    
    /**
     * @param _addr The address for which is being checked how many milligrams the address owner
     * (i.e. the registered member) can buy.
     * @return The total amount of milligrams the address owner can buy.
     * */
    function getMilligramsMemberCanBuy(address _addr) public view returns(uint256) {
        uint256 milligrams = memberPurchases[_addr][monthNo];
        if(milligrams >= maxGramsPerMonth.mul(1000)) {
            return 0;
        } else {
            return (maxGramsPerMonth.mul(1000)).sub(milligrams);
        }
    }
    
    

    /**
     * @param _id The member ID for which is being checked how many milligrams the ID owner
     * (i.e. the registered member) can buy.
     * @return The total amount of milligrams the ID owner can buy.
     * */
    function getMilligramsMemberCanBuy(uint256 _id) public view returns(uint256) {
        uint256 milligrams = memberPurchases[getMemberAddrById(_id)][monthNo];
        if(milligrams >= maxGramsPerMonth.mul(1000)) {
            return 0;
        } else {
            return (maxGramsPerMonth.mul(1000)).sub(milligrams);
        }
    }


    
    /**
     * ONLY MEMBER FUNCTIONS
     * */
     
     /**
      * Allows members to buy cannabis.
      * @param _price The total amount of ELYC tokens that should be paid.
      * @param _milligrams The total amount of milligrams which is being purchased 
      * @param _vendor The vendors address 
      * @return true if the function executes successfully, false otherwise
      * */
    function buyCannabis(uint256 _price, uint256 _milligrams, address _vendor) public onlyMembers returns(bool) {
        require(_milligrams > 0 && _price > 0 && _vendor != address(0));
        require(_milligrams <= getMilligramsMemberCanBuy(msg.sender));
        ELYC.transferFrom(msg.sender, _vendor, _price);
        memberPurchases[msg.sender][monthNo] = memberPurchases[msg.sender][monthNo].add(_milligrams);
        emit CannabisPurchaseMade(msg.sender, _milligrams, _price, _vendor, block.number);
        return true;
    }
    
    
    
    /**
     * ONLY OWNER FUNCTIONS
     * */
     
    /**
     * Allows the owner of this contract to add new members.
     * @param _addr The address of the new member. 
     * @return true if the function executes successfully, false otherwise.
     * */
    function addMember(address _addr) public onlyOwner returns(bool) {
        require(!addrIsMember[_addr]);
        addrIsMember[_addr] = true;
        numOfMembers += 1;
        memberIdByAddr[_addr] = numOfMembers;
        memberAddrById[numOfMembers] = _addr;
        emit NewMemberAdded(_addr, numOfMembers, block.number);
        //assignment of owner variable made to overcome bug found in EVM which 
        //caused the owner address to overflow to 0x00...01
        owner = msg.sender;
        return true;
    }
    
    
    /**
     * Allows the owner to change the maximum amount of grams which members can buy 
     * each month. 
     * @param _newMax The new maximum amount of grams 
     * @return true if the function executes successfully, false otherwise.
     * */
    function setMaxGramsPerMonth(uint256 _newMax) public onlyOwner returns(bool) {
        require(_newMax != maxGramsPerMonth && _newMax > 0);
        emit MaxGramsPerMonthChanged(maxGramsPerMonth, _newMax);
        maxGramsPerMonth = _newMax;
        return true;
    }
    
    
    /**
     * Allows the owner to add members to the blacklist using the member's address
     * @param _addr The address of the member who is to be blacklisted
     * @return true if the function executes successfully, false otherwise.
     * */
    function addMemberToBlacklist(address _addr) public onlyOwner returns(bool) {
        emit MemberBlacklisted(_addr, getMemberIdByAddr(_addr), block.number);
        blacklist[_addr] = true;
        return true;
    }
    
    
    /**
     * Allows the owner to add members to the blacklist using the member's ID
     * @param _id The ID of the member who is to be blacklisted.
     * @return true if the function executes successfully, false otherwise.
     * */
    function addMemberToBlacklist(uint256 _id) public onlyOwner returns(bool) {
        emit MemberBlacklisted(getMemberAddrById(_id), _id, block.number);
        blacklist[getMemberAddrById(_id)] = true;
        return true;
    }
    
    
    /**
     * Allows the owner to remove members from the blacklist using the member's address. 
     * @param _addr The address of the member who is to be removed from the blacklist. 
     * @return true if the function executes successfully, false otherwise.
     * */
    function removeMemberFromBlacklist(address _addr) public onlyOwner returns(bool) {
        emit MemberRemovedFromBlacklist(_addr, getMemberIdByAddr(_addr), block.number);
        blacklist[_addr] = false;
        return true;
    }
    
    
    /**
     * Allows the owner to remove members from the blacklist using the member's ID.
     * @param _id The ID of the member who is to be removed from the blacklist.
     * @return true if the function executes successfully, false otherwise.
     * */
    function removeMemberFromBlacklist(uint256 _id) public onlyOwner returns(bool) {
        emit MemberRemovedFromBlacklist(getMemberAddrById(_id), _id, block.number);
        blacklist[getMemberAddrById(_id)] = false;
        return true;
    }
    
    
    /**
     * Allows the owner to withdraw any ERC20 token which may have been sent to this 
     * contract address by mistake. 
     * @param _addressOfToken The contract address of the ERC20 token
     * @param _recipient The receiver of the token. 
     * */
    function withdrawAnyERC20(address _addressOfToken, address _recipient) public onlyOwner {
        ERC20 token = ERC20(_addressOfToken);
        token.transfer(_recipient, token.balanceOf(address(this)));
    }
    
    
    /**
     * Allows the owner to update the monnth on the contract
     * */
    function incrementMonthNo() public onlyOwner {
        emit MonthNumberIncremented(now);
        monthNo = monthNo.add(1);
    }
}














