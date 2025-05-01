// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;

import "@openzeppelin/contracts/access/AccessControl.sol";
import {ContractRegistry} from "@flarenetwork/flare-periphery-contracts/coston2/ContractRegistry.sol";
/* THIS IS A TEST IMPORT, in production use: import {FtsoV2Interface} from "@flarenetwork/flare-periphery-contracts/coston2/FtsoV2Interface.sol"; */
import {TestFtsoV2Interface} from "@flarenetwork/flare-periphery-contracts/coston2/TestFtsoV2Interface.sol";


contract MegustaFlr is AccessControl{
    TestFtsoV2Interface internal ftsoV2;
    bytes21[] public feedIds = [
    bytes21(0x01464c522f55534400000000000000000000000000), // FLR/USD
    bytes21(0x014554482f55534400000000000000000000000000) // ETH/USD
    ];


    struct tournament {
        uint tid; // if of the tournament
        uint gid; // id of the game played
        uint duration; // 1 is hourly, 2 is daily, 3 is weekly, 4 is monthly
        uint min_participants; 
        uint start; 
        uint end; 
    }

    struct stournament {            //stournaments are special tournaments that only admins can create
        uint tid;                       //they are rarer than the normal tournaments with usually 
        uint gid;                           //greater entry fees and rewards
        uint fee; // the entry fee
        uint start; 
        uint end; 
    }

    struct performance {
        uint tid;
        address player;
        uint score;
        uint score_type;  // 0 means lower score is better, 1 means higher is better 
        uint timestamp;
    }

    constructor(){
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    uint count = 0;
    uint constant MIN_PART = 10;
    bytes32 public constant ADMIN_ROLE =   keccak256("ADMIN_ROLE");  
    

    mapping (uint => tournament) public tournaments;
    mapping (uint => stournament) public stournaments;
    mapping (uint => performance[]) public performances;
    mapping (uint => mapping (uint => uint)) public last_created; //(gid => (duration => timestamp))
    
    function addManager(address target) public onlyRole(DEFAULT_ADMIN_ROLE){
        _grantRole(ADMIN_ROLE, target);
    }

    function removeManager(address target) public onlyRole(DEFAULT_ADMIN_ROLE){
        _revokeRole(ADMIN_ROLE, target);
    }

    function create_sp_tournament(uint g_id, uint daycount, uint entry) public onlyRole(ADMIN_ROLE) {
        uint c = count + 1;
        require (daycount <= 60, "must wind up in 2 months");
        require (entry > 3, "entry must be worth at least 3 tickets");
        uint timenow = block.timestamp;
        uint st = timenow;
        uint ed = timenow + daycount*24*60*60;
        stournament memory s = stournament({
            tid: c,
            gid: g_id,
            fee: entry,
            start: st,
            end: ed
        });
        stournaments[c] = s;
        count = c;
    }
    
    function create_tournament(uint g_id, uint dur, bool mp_flag) public{
        uint c = count + 1;
        require (dur == 1 || dur == 2 || dur == 3 || dur == 4, "duration is 1, 2, 3, or 4");
        uint last_instance = last_created[g_id][dur];
        uint timenow = block.timestamp;
        uint st = 0;
        uint ed = 0;
        uint mp = MIN_PART;

        if (dur == 2){
            require (last_instance + 24*60*60 < timenow, "such tournament already ongoing");
            st = timenow;
            ed = timenow + (24*60*60);
            if (mp_flag){
                mp = 50;
            }

        }
        else if (dur == 3){
            require (last_instance + 7*24*60*60 < timenow, "such tournament already ongoing");
            st = timenow;
            ed = timenow + (7*24*60*60);
            if (mp_flag){
                mp = 100;
            }
        }
        else if (dur == 4){
            require (last_instance + 30*24*60*60 < timenow, "such tournament already ongoing");
            st = timenow;
            ed = timenow + (30*24*60*60);
            if (mp_flag){
                mp = 300;
            }
        }
        else {
            require (last_instance + 60 < timenow, "last such tournament created within a minute back");
            st = timenow;
            ed = timenow + (60*60);
            if (mp_flag){
                mp = 20;
            }
        }

        tournament memory t = tournament({
            tid: c,
            gid: g_id,
            duration: dur,
            min_participants: mp,
            start: st,
            end: ed
        });

        tournaments[c] = t;
        last_created[g_id][dur] = timenow;
        count = c;
    }
    
    // ftso is invoked to ensure parity between playing prices and rewards on flare and ethereum network tournaments
    function play_sp_game(uint s_id) public payable {
        stournament memory s = stournaments[s_id];
        require (s.gid != 0, "tournament does not exist");
        ftsoV2 = ContractRegistry.getTestFtsoV2();
        (uint256[] memory feedValue, int8[] memory decimals, uint64 timestamp) = ftsoV2.getFeedsById(feedIds);
        uint num = feedValue[1] * uint256(uint8(decimals[0]));
        uint den = feedValue[0] * uint256(uint8(decimals[1]));
        uint n = s.fee;
        require (n != 0, "something went wrong");
        require(
            msg.value >= ((n * num * 0.005 ether) / den), 
            "each ticket costs 0.005 ether, are you out of balance?"
        );
    }

   // ftso is invoked to ensure parity between playing prices and rewards on flare and ethereum network tournaments
    function play_game(uint t_id) public payable {
        tournament memory t = tournaments[t_id];
        require (t.gid != 0, "tournament does not exist");
        uint n = 0;
        if (t.duration == 1){
            n = 1;
        }
        else if (t.duration == 2){
            n = 5;
        }
        else if (t.duration == 3){
            n = 10;
        }
        else if (t.duration == 4){
            n = 15;
        }
        else {
            n = 0;
        }
        require (n != 0, "something went wrong");
        ftsoV2 = ContractRegistry.getTestFtsoV2();
        (uint256[] memory feedValue, int8[] memory decimals, uint64 timestamp) = ftsoV2.getFeedsById(feedIds);
        uint num = feedValue[1] * uint256(uint8(decimals[0]));
        uint den = feedValue[0] * uint256(uint8(decimals[1]));
        require(
            msg.value >= (n * num * 0.005 ether)/den, 
            "each ticket costs 0.005 ether, are you out of balance?"
        );
    }

    
   function record_sp_score(uint s_id, address pl, uint scr, uint scr_tp) public onlyRole(ADMIN_ROLE) {
        performance memory p = performance({
            tid: s_id,
            player: pl,
            score: scr,
            score_type: scr_tp,
            timestamp: block.timestamp
        });
        

        performance[] storage plist = performances[s_id];
        plist.push(p);
        
        
        performances[s_id] = plist;

    }

    function record_score(uint t_id, address pl, uint scr, uint scr_tp) public onlyRole(ADMIN_ROLE) {
        performance memory p = performance({
            tid: t_id,
            player: pl,
            score: scr,
            score_type: scr_tp,
            timestamp: block.timestamp
        });
        

        performance[] storage plist = performances[t_id];
        plist.push(p);
        
        
        performances[t_id] = plist;

    }

    function distribute_sp_rewards(uint s_id, address[] memory winners) public onlyRole(ADMIN_ROLE) {
        stournament memory s = stournaments[s_id];
        uint timenow = block.timestamp;
        require (s.end <= timenow, "tournament is ongoing");
        require (s.gid != 0, "tournament does not exist");
        
        uint n = s.fee;

        performance[] memory plist = performances[s_id];
        uint p = plist.length;
        uint w = winners.length;
        require (p / 2 == w, "not enough chosen winners");

        ftsoV2 = ContractRegistry.getTestFtsoV2();
        (uint256[] memory feedValue, int8[] memory decimals, uint64 timestamp) = ftsoV2.getFeedsById(feedIds);
        uint num = feedValue[1] * uint256(uint8(decimals[0]));
        uint den = feedValue[0] * uint256(uint8(decimals[1]));

        if (p < 20){
            uint i = 0;
            while (i < p){
                payable(plist[i].player).transfer((n * num * 0.005 ether)/den);
                i = i + 1;
            }
        }
        else {
            uint i = 0;
            uint amt = 5000000000000000 * n +  (5000000000000000 * n)/(2);
            while(i < w){
                payable(winners[i]).transfer((amt * num)/den);
                i = i + 1;
                amt = amt + (n * 5000000000000000 * 2)/(p - 2)  ;

            }
        }
    }
    
    
    
    function distribute_rewards(uint t_id, address[] memory winners) public onlyRole(ADMIN_ROLE) {
        tournament memory t = tournaments[t_id];
        uint timenow = block.timestamp;
        require (t.end <= timenow, "tournament is ongoing");
        require (t.gid != 0, "tournament does not exist");
        
        uint n = 0;
        if (t.duration == 1){
            n = 1;
        }
        else if (t.duration == 2){
            n = 5;
        }
        else if (t.duration == 3){
            n = 10;
        }
        else if (t.duration == 4){
            n = 15;
        }
        else {
            n = 0;
        }
        require (n != 0, "something went wrong");

        
        ftsoV2 = ContractRegistry.getTestFtsoV2();
        (uint256[] memory feedValue, int8[] memory decimals, uint64 timestamp) = ftsoV2.getFeedsById(feedIds);
        uint num = feedValue[1] * uint256(uint8(decimals[0]));
        uint den = feedValue[0] * uint256(uint8(decimals[1]));

        performance[] memory plist = performances[t_id];
        uint p = plist.length;
        uint w = winners.length;
        require (p / 2 == w, "not enough chosen winners");
        if (p < t.min_participants){
            uint i = 0;
            while (i < p){
                payable(plist[i].player).transfer((n * num* 0.005 ether)/den);
                i = i + 1;
            }
        }
        else {
            uint i = 0;
            uint amt = 5000000000000000 * n +  (5000000000000000 * n)/(2);
            while(i < w){
                payable(winners[i]).transfer((amt * num)/den);
                i = i + 1;
                amt = amt + (n * 5000000000000000 * 2)/(p - 2)  ;

            }
        }
    }

    


    

    

   
    // getter as in: https://stackoverflow.com/questions/74249392/how-can-i-access-a-solidity-mapping-address-struct-using-ether-js
    
}
