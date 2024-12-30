// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;


contract Megusta {

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


    uint count = 0;
    address ADMIN =   0xD0dC8A261Ad1B75A92C5e502AE10c3Fde042b879;  
   
    mapping (uint => tournament) public tournaments;
    mapping (uint => performance[]) public performances;
    mapping (uint => mapping (uint => uint)) public last_created; //(gid => (duration => timestamp))
    mapping (address => mapping (uint => uint)) public tickets; // user add => (game id => number)
    
    function create_tournament(uint g_id, uint dur, uint mp) public{
        uint c = count + 1;
        require (dur == 1 || dur == 2 || dur == 3 || dur == 4, "duration is 1, 2, 3, or 4");
        require (mp == 20 || mp == 50 || mp == 100 || mp == 500 || mp == 0, "min participants is 20, 50, 100, 500, or 0 for open");
        uint last_instance = last_created[g_id][dur];
        uint timenow = block.timestamp;
        uint st = 0;
        uint ed = 0;

        if (dur == 2){
            require (last_instance + 24*60*60 < timenow, "such tournament already ongoing");
            st = timenow;
            ed = timenow + (24*60*60);

        }
        else if (dur == 3){
            require (last_instance + 7*24*60*60 < timenow, "such tournament already ongoing");
            st = timenow;
            ed = timenow + (7*24*60*60);
        }
        else if (dur == 4){
            require (last_instance + 30*24*60*60 < timenow, "such tournament already ongoing");
            st = timenow;
            ed = timenow + (30*24*60*60);
        }
        else {
            require (last_instance + 60 < timenow, "last such tournament created within a minute back");
            st = timenow;
            ed = timenow + (60*60);
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
    
    

   
    function buy_tickets(uint n, uint g_id) public payable {
        require(
            msg.value >= n * 0.005 ether, 
            "each ticket costs 0.005 ether, are you out of balance?"
        );
        uint tix = tickets[msg.sender][g_id];
        tickets[msg.sender][g_id] = tix + n;
    }

  
   

    function record_score(uint t_id, address pl, uint dur, uint g_id, uint scr, uint scr_tp) public {
        require (msg.sender == ADMIN, "this is an admin only function");
        performance memory p = performance({
            tid: t_id,
            player: pl,
            score: scr,
            score_type: scr_tp,
            timestamp: block.timestamp
        });
        uint tix = tickets[pl][g_id];
        if (dur == 1){
            require (tix >= 1, "need a ticket to play");
            tickets[pl][g_id] = tix - 1;
        }
        else if (dur == 2){
            require (tix >= 5, "need 5 tickets to play");
            tickets[pl][g_id] = tix - 5;
        }
        else if (dur == 3){
            require (tix >= 10, "need 10 tickets to play");
            tickets[pl][g_id] = tix - 10;
        }
        else if (dur == 4){
            require (tix >= 15, "need 15 tickets to play");
            tickets[pl][g_id] = tix - 15;
        }
        else {
            require (false, "something went wrong");
        }

        performance[] storage plist = performances[t_id];
        plist.push(p);
        
        
        performances[t_id] = plist;

    }

    


    

    

   
    // getter as in: https://stackoverflow.com/questions/74249392/how-can-i-access-a-solidity-mapping-address-struct-using-ether-js
    
}
