#ifndef __SIMPLE_SESSION_MQH__
#define __SIMPLE_SESSION_MQH__

// Thai timezone session check (GMT+7)
bool InLondonKillzone() {
    MqlDateTime dt;
    TimeToStruct(TimeCurrent() + 7*3600, dt); // Convert to Thai time
    
    // London Killzone: 14:00-17:00 Thai time
    return (dt.hour >= 14 && dt.hour < 17);
}

bool InNYKillzone() {
    MqlDateTime dt;
    TimeToStruct(TimeCurrent() + 7*3600, dt); // Convert to Thai time
    
    // NY Killzone: 19:30-23:00 Thai time
    return (dt.hour >= 19 && dt.hour < 23) && 
           (dt.hour > 19 || (dt.hour == 19 && dt.min >= 30));
}

// Legacy functions for compatibility
bool InLondonSession() {
    return InLondonKillzone();
}

bool InNYSession() {
    return InNYKillzone();
}

bool InAnyTradingSession() {
    return InLondonSession() || InNYSession();
}

// Debug session info
void PrintSessionInfo() {
    MqlDateTime dt;
    TimeToStruct(TimeCurrent(), dt);
    
    Print("[SESSION] Current GMT hour: ", dt.hour, 
          " London: ", InLondonSession() ? "ACTIVE" : "CLOSED",
          " NY: ", InNYSession() ? "ACTIVE" : "CLOSED");
}

#endif // __SIMPLE_SESSION_MQH__ 