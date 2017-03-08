pragma solidity ^0.4.9;

contract Series {
    address public mainContract;
    address public extraContract;
    mapping(bytes4=>uint32) _sizes;

    struct Member {
        string name; // Legal name of memeber
        string addr; // Legal identification of the member
        uint shares; //Amount of shares, 0 being not a member/ex-member
        bool manager; // This is legal: If this is "true", the partner is a manager, if false, the partner is a normal member
        uint amount; //Total amount of ether contributed by this user
    }
    
    struct Proposal {
        address addr;
        bool executed;
        uint votes;
        uint amount;
        bytes description;
    }
    
    string public standard = 'Token 0.1';
    
    uint public totalSupply; // Total amount of shares, once set, this is immutable
    address public seriesOrganization = 0x0D47d4aEa9dA60953Fd4ae5C47d2165977C7fbeA;
    address public creator;
    string public industry;
    string public addr;
    mapping (address => Member) public members;
    Proposal[] public proposals; //Contains votes for a proposal
    
    //These "tokenizes" the contract:
    string public name;
    string public symbol;
    uint8 public decimals = 0;
    
    //The events:
    event SeriesCreated (address addr, address mainCompany, uint id);
    event Transfer (address from, address to, uint shares);
    event ChangedName (address who, string to);
    event ChangedMemberAddress (address who, string to);
    event Resigned (address who);
    event SetManager (address who, bool isManager);
    event SetIndustry (string newIndustry);
    event SetName (string newName);
    event CreatedProposal (bytes32 proposalId);
    event ConfirmedProposal (address who, bytes32 what);
    event AddedSizeForFunction (bytes4 functionSignature, uint32 size);
    
    /// @dev This modifier is used with all of the functions requiring authorisation. Previously used msg.value check is not needed anymore.
    modifier ifAuthorised {
        if (members[msg.sender].shares == 0 && msg.sender != creator)
            throw;

        _;
    }
    
    /// @dev This modifier is used to check if the user is a manager
    modifier ifManager {
        if (members[msg.sender].manager == false)
            throw;

        _;
    }
    
    /// @dev This function can be 
    function isExpired () {
        //Ropsten: 0x0640751ac23676f02cb7cddeaf30123d3b1268e3
        //Mainnet: 0x0D47d4aEa9dA60953Fd4ae5C47d2165977C7fbeA
        address seriesOrganization = 0x0D47d4aEa9dA60953Fd4ae5C47d2165977C7fbeA;
        if (EtherprisesLLC(seriesOrganization).isExpired(this)) {
            if (!seriesOrganization.call.gas(90000).value(1 ether)(bytes4(sha3("payFee()"))))
                suicide(seriesOrganization);
        }
    }
    
    /// @dev This is the constructor
    //function createSeries (bytes32 newName, uint id, uint newShares, string newIndustry, string newSymbol, address newManager) payable {
    function Series (bytes newName, uint id, uint newShares, string newIndustry, string newSymbol, address newManager, address newExtraContract) {
        if (newShares < 1)
            throw;

        totalSupply = newShares;
        industry = newIndustry;
        name = string(newName);
        symbol = newSymbol;
        extraContract = newExtraContract;
        creator = msg.sender;
        
        //The organisation can own it's own shares when token support is in
        members[newManager] = Member ("", "", totalSupply, true, 0);
        
        SeriesCreated (this, msg.sender, id);
    }
    
    /// @dev Here we "tokenize" our contract, so wallets can use this as a token.
    /// @param target Address whose balance we want to query.
    function balanceOf(address target) constant returns(uint256 balance) {
        return members[target].shares;
    }
    
    /// @notice This transfers `amount` shares to `target.address()`. This is irreversible, are  you OK with this?
    /// @dev This transfers shares from the current shareholder to a future shareholder, and will create one if it does not exists. This 
    /// @param target Address of the account which will receive the shares.
    /// @param amount Amount of shares, 0 being none, and 1 being one share, and so on.
    function transfer (address target, uint256 amount) ifAuthorised {
        if (amount == 0 || members[msg.sender].shares < amount)
            throw;
        
        members[msg.sender].shares -= amount;
        if (members[target].shares > 0) {
            members[target].shares += amount;
        } else {
            members[target].shares = amount;
            members[target].manager = false;
        }
        
        Transfer (msg.sender, target, amount);
    }
    
    /// @dev This function is used to change user's own name. Ethereum is anonymous by design, but Delaware requires managers and members to report their names.
    /// @param newName User's new name.
    function changeMemberName (string newName) ifAuthorised {
        members[msg.sender].name = newName;
        
        ChangedName (msg.sender, newName);
    }
    
    /// @dev This function is used to change user's own address. Ethereum is anonymous by design, but Delaware requires managers and members to report address.
    /// @param newAddr User's new address, containing street, city, region and country
    function changeMemberAddress (string newAddr) ifAuthorised {
        members[msg.sender].addr = newAddr;
        
        ChangedMemberAddress (msg.sender, newAddr);
    }
    
    /// @notice WARNING! This will remove your existance from the company, this is irreversible and instant. This will not terminate the company. Are you really really sure?
    /// @dev This is required by the law of Delaware, a person must be able to resign from a company. This will not terminate the company.
    function resign () {
        if (bytes(members[msg.sender].name).length == 0 || members[msg.sender].shares > 0)
            throw;
            
        members[msg.sender].name = "Resigned member";
        members[msg.sender].addr = "Resigned member";
        
        Resigned (msg.sender);
    }
    
    /// @notice This sets member's liability status, either to manager, or a normal memeber. Beware, that this has legal implications, and decission must be done with other general partners.
    /// @dev This is another function added for legal reason, using this, you can define is a member a manager or a normal member.
    /// @param target The user we want to define.
    /// @param isManager Will the target be a manager or not
    function setManager (address target, bool isManager) ifAuthorised ifManager {
        members[target].manager = isManager;
        
        SetManager (target, isManager);
    }
    
    /// @dev This sets the industry of the company. This might have legal implications.
    /// @param newIndustry New industry, where there company is going to operate.
    function setIndustry (string newIndustry) ifAuthorised ifManager {
        industry = newIndustry;
        
        SetIndustry (newIndustry);
    }
    
    /// @dev This creates a new proposal for voting.
    /// @param _to Address of the proposal, where the money will be eventually sent
    /// @param _data Short description of the proposal, or the forwarded payload
    /// @param _value Proposed amount in weis for a proposal
    function execute(address _to, uint _value, bytes _data) ifAuthorised returns (bytes32 _id) {
        bytes32 id = bytes32(proposals.length);
        Proposal memory newProposal = Proposal(_to, false, 0, _value, _data);
        
        proposals.push (newProposal);
        
        CreatedProposal(id);
        
        return id;
    }
    
    /// @dev This votes for proposal, and executes is automatically if received enough votes.
    /// @param _id Incremental ID of the proposal, where the money will be eventually sent
    function confirm(bytes32 _id) ifAuthorised returns (bool _success) {
        if (uint(_id) >= proposals.length)
            throw;

        uint id = uint(_id);
        
        if (proposals[id].executed)
            throw;
        
        proposals[id].votes += members[msg.sender].shares;
        
        ConfirmedProposal (msg.sender, _id);
        
        if (proposals[id].votes > (totalSupply/2)) {
            if (proposals[id].addr.call.value(proposals[id].amount)(proposals[id].description)) {
                proposals[id].executed = true;
                
                return true;
            }
        }
        
        return false;
    }
    
    function addSizeForFunction (bytes4 sig, uint32 newSize) ifAuthorised {
        _sizes[sig] = newSize;
        
        AddedSizeForFunction (sig, newSize);
    }
    
    //This wasn't deployed with the initial release, since it still needs some work:
    /** function callOther (address other, uint8 returnSize, bytes _calldata) ifAuthorised ifManager {
        var target = other;
        var calldatasize = _calldata.length;
        
        assembly{

			//gas needs to be uint:ed
			let g := and(gas,0xEFFFFFFF)
			let o_code := mload(0x40)

			//callcode or delegatecall or call
			let retval := call(g
				, target //address
				, 0 //value
				, _calldata //mem in
				, calldatasize //mem_insz
				, _calldata //reuse mem
				, returnSize) //Hardcoded to 32 b return value
				
			// Check return value
			// 0 == it threw, so we do aswell by jumping to 
			// bad destination (02)
			jumpi(0x02,iszero(retval))

			// return(p,s) : end execution, return data mem[p..(p+s))
			return(o_code,returnSize)
		}
    } **/
    
    /// @dev The default fallback function: This also calls the extra contract if one is specified
    function () payable {
        if (msg.sender == creator) {
            members[msg.sender].amount += msg.value;
            return;
        }
        
        if (extraContract > 0) {
            bytes4 sig;
            assembly { sig := calldataload(0) }
            var len = _sizes[sig];
            var target = extraContract;
            
            assembly {
                calldatacopy(0x0, 0x0, calldatasize)
                let retval := delegatecall(sub(gas, 10000), target, 0x0, calldatasize, 0, len)
                return(0, len)
            }
        } else {
            if (msg.sender == seriesOrganization || members[msg.sender].shares > 0)
                members[msg.sender].amount += msg.value;
            else
                throw;
        }
    }
}
