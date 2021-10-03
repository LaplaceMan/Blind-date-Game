// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;   

import "./ReentrancyGuard.sol";
import "./Ownable.sol";
import "./Token/ERC20.sol";

contract Match is ReentrancyGuard, Ownable, ERC20 {
    //Base system information.
    uint256 public interval;
    uint256 public price;
    uint256 public pool;

    enum Gender{Woman, Man}

    partInfo[] private participation;   
    
    string[] private interestings;
    
    mapping(string => bool) isExist;

    mapping(address => bool) haveJoin;

    mapping(address => uint256) time;

    mapping(string => mapping(Gender => uint256[])) contact;


    struct partInfo {
        address  who;
        string   contactInfo;
        string   infoHash;
    }

    event newJoiner(uint8 gender, string[3] interest);

    constructor(uint256 Interval, uint256 Price, string memory name, string memory symbol) ERC20(name, symbol) Ownable() {
        interval = Interval;
        price = Price;
        pool = 0;
    }

    //Platform setting.
    function changeInterval(uint256 newInterval) public onlyOwner returns(bool) {
        interval = newInterval;
        return true;
    }

    function changePrice(uint256 newPrice) public onlyOwner returns(bool) {
        price = newPrice;
        return true;
    }

    //添加个人信息（参加活动）.
    //gender: 自己的性别，0为女性，1为男性.
    //hope[3]: 自己的兴趣，可以输入3个.
    //tel: 经过对称加密的联系方式.
    //hash: 哈希后的联系方式.
    function join(uint8 gender, string[3] memory hope, string memory tel, string memory hash) public payable returns(uint256) {
        require(haveJoin[msg.sender] == false);
        require(msg.value >= price);
        pool += msg.value/2;

        participation.push(partInfo({
                who: msg.sender,
                contactInfo: tel,
                infoHash: hash
            }));
        uint256 index = participation.length - 1;
        haveJoin[msg.sender] = true;

        for(uint8 i = 0; i < hope.length; i++) {
            contact[hope[i]][Gender(gender)].push(index);
            if(isExist[hope[i]] == false) {
                interestings.push(hope[i]);
                isExist[hope[i]] = true;
            }
        }

        emit newJoiner(gender, hope);

        return index;

    } 
    //申请异性的联系方式（参加活动）.
    //gender: 希望获得哪个性别用户的联系方式.
    //seed: 随机数种子.
    //hope: 希望获得拥有哪些兴趣的异性用户的联系方式.
    function claim(uint8 gender, uint256 seed, string[3] memory hope) public payable nonReentrant returns(string memory) {
        require(block.timestamp > time[msg.sender] + interval);
        require(msg.value >= price);
        pool += msg.value/2;

        for(uint8 i = 0; i < hope.length; i++) {
            require(isExist[hope[i]] == true, string(abi.encodePacked("The user interested in ", hope[i], "does not exist")));
        }
        string memory URI = getURI(gender, seed, hope);
        time[msg.sender] = block.timestamp;
        return URI;
    }

    function pluck(string memory symbol, uint256 seed, uint256[] memory sourceArray) internal returns (string memory) {
        if(bytes(symbol).length == 0) {
            return '';
        }
        uint256 rand = random(string(abi.encodePacked(symbol, toString(seed))));
        uint256 index = sourceArray[rand % sourceArray.length];
        string memory output = participation[index].infoHash;
        _mint(participation[index].who, 1);
        return output;
    }

    function getURI(uint8 gender, uint256 seed, string[3] memory hope) internal returns (string memory) { 
        string[12] memory parts;
        
        parts[0] = hope[0];

        parts[1] = ':';

        parts[2] = pluck(hope[0], seed, contact[hope[0]][Gender(gender)]);

        parts[3] = '\n';

        parts[4] = hope[1];

        parts[5] = ':';

        parts[6] = pluck(hope[1], seed, contact[hope[1]][Gender(gender)]);

        parts[7] = '\n';

        parts[8] = hope[2];

        parts[9] = ':';

        parts[10] = pluck(hope[2], seed, contact[hope[2]][Gender(gender)]);

        parts[11] = '.';


        string memory output = string(abi.encodePacked(parts[0], parts[1], parts[2], parts[3], parts[4], parts[5], parts[6], parts[7], parts[8]));
        output = string(abi.encodePacked(output, parts[9], parts[10], parts[11]));

        return output;
    }
    //Platform withdraw contract CBDC.
    function withdraw() public onlyOwner returns(uint256) {
        uint256 profit = address(this).balance - pool;
        payable(msg.sender).transfer(profit);

        return profit;
    }
    //Exchange credit for CBDC.
    function exchange(uint256 amount) public nonReentrant returns(uint256) {
        _burn(msg.sender, amount);
        uint256 total = totalSupply();
        uint256 get = amount*pool/total;
        payable(msg.sender).transfer(get);
        
        return get;
    }
    // 辅助功能.    
    function random(string memory input) internal pure returns (uint256) {
        return uint256(keccak256(abi.encodePacked(input)));
    }

    function toString(uint256 value) internal pure returns (string memory) {
    // Inspired by OraclizeAPI's implementation - MIT license
    // https://github.com/oraclize/ethereum-api/blob/b42146b063c7d6ee1358846c198246239e9360e8/oraclizeAPI_0.4.25.sol

        if (value == 0) {
            return "0";
        }
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }
        return string(buffer);
    }

}
