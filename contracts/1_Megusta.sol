// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;

import "@openzeppelin/contracts/access/AccessControl.sol";

contract Megusta is AccessControl{

    struct tournament {
        uint tid; // if of the tournament
        uint gid; // id of the game played
        uint duration; // 1 is hourly, 2 is daily, 3 is weekly, 4 is monthly
        uint min_participants; 
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
    bytes32 public constant ADMIN_ROLE =   keccak256("ADMIN_ROLE");  
   
    mapping (uint => tournament) public tournaments;
    mapping (uint => performance[]) public performances;
    mapping (uint => mapping (uint => uint)) public last_created; //(gid => (duration => timestamp))
    
    function addManager(address target) public onlyRole(DEFAULT_ADMIN_ROLE){
        _grantRole(ADMIN_ROLE, target);
    }
    
    function create_tournament(uint g_id, uint dur, bool mp_flag) public{
        uint c = count + 1;
        require (dur == 1 || dur == 2 || dur == 3 || dur == 4, "duration is 1, 2, 3, or 4");
        uint last_instance = last_created[g_id][dur];
        uint timenow = block.timestamp;
        uint st = 0;
        uint ed = 0;
        uint mp = 0;

        if (dur == 2){
            require (last_instance + 24*60*60 < timenow, "such tournament already ongoing");
            st = timenow;
            ed = timenow + (24*60*60);
            if (mp_flag){
                mp = 20;
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
                mp = 500;
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
        require(
            msg.value >= n * 0.005 ether, 
            "each ticket costs 0.005 ether, are you out of balance?"
        );
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

        performance[] memory plist = performances[t_id];
        require (plist.length / 2 == winners.length, "not enough chosen winners");
        if (plist.length < t.min_participants){
            uint i = 0;
            while (i < plist.length){
                payable(plist[i].player).transfer(n * 0.005 ether);
                i = i + 1;
            }
        }
        else {
            uint i = 0;
            while(i < plist.length){
                payable(winners[i]).transfer(n * 0.01 ether);
                i = i + 1;
            }
        }
    }

    


    

    

   
    // getter as in: https://stackoverflow.com/questions/74249392/how-can-i-access-a-solidity-mapping-address-struct-using-ether-js
    
}
