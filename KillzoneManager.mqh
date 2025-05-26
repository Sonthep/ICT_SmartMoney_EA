#ifndef __KILLZONE_MANAGER_MQH__
#define __KILLZONE_MANAGER_MQH__

//+------------------------------------------------------------------+
//| Killzone Manager for Session-Based Trading                     |
//| Manages London and NY killzone timing                          |
//+------------------------------------------------------------------+
class CKillzoneManager {
private:
    bool m_useLondonKZ;
    bool m_useNYKZ;
    int m_timezoneOffset;
    
    // Killzone times (GMT)
    int m_londonStartHour;
    int m_londonStartMin;
    int m_londonEndHour;
    int m_londonEndMin;
    
    int m_nyStartHour;
    int m_nyStartMin;
    int m_nyEndHour;
    int m_nyEndMin;
    
public:
    CKillzoneManager() {
        m_useLondonKZ = true;
        m_useNYKZ = true;
        m_timezoneOffset = 0;
        
        // London Killzone: 08:00-10:30 GMT
        m_londonStartHour = 8;
        m_londonStartMin = 0;
        m_londonEndHour = 10;
        m_londonEndMin = 30;
        
        // NY Killzone: 13:00-16:00 GMT
        m_nyStartHour = 13;
        m_nyStartMin = 0;
        m_nyEndHour = 16;
        m_nyEndMin = 0;
    }
    
    ~CKillzoneManager() {}
    
    //+------------------------------------------------------------------+
    //| Set killzone parameters                                        |
    //+------------------------------------------------------------------+
    void SetParameters(bool useLondon, bool useNY, int timezoneOffset) {
        m_useLondonKZ = useLondon;
        m_useNYKZ = useNY;
        m_timezoneOffset = timezoneOffset;
    }
    
    //+------------------------------------------------------------------+
    //| Set custom killzone times                                      |
    //+------------------------------------------------------------------+
    void SetLondonKillzone(int startHour, int startMin, int endHour, int endMin) {
        m_londonStartHour = startHour;
        m_londonStartMin = startMin;
        m_londonEndHour = endHour;
        m_londonEndMin = endMin;
    }
    
    void SetNYKillzone(int startHour, int startMin, int endHour, int endMin) {
        m_nyStartHour = startHour;
        m_nyStartMin = startMin;
        m_nyEndHour = endHour;
        m_nyEndMin = endMin;
    }
    
    //+------------------------------------------------------------------+
    //| Check if currently in any killzone                             |
    //+------------------------------------------------------------------+
    bool IsInKillzone() {
        if(m_useLondonKZ && IsInLondonKillzone()) return true;
        if(m_useNYKZ && IsInNYKillzone()) return true;
        return false;
    }
    
    //+------------------------------------------------------------------+
    //| Check if in London killzone                                    |
    //+------------------------------------------------------------------+
    bool IsInLondonKillzone() {
        if(!m_useLondonKZ) return false;
        
        MqlDateTime dt;
        datetime gmtTime = TimeCurrent() - (m_timezoneOffset * 3600);
        TimeToStruct(gmtTime, dt);
        
        return IsTimeInRange(dt.hour, dt.min, 
                           m_londonStartHour, m_londonStartMin,
                           m_londonEndHour, m_londonEndMin);
    }
    
    //+------------------------------------------------------------------+
    //| Check if in NY killzone                                        |
    //+------------------------------------------------------------------+
    bool IsInNYKillzone() {
        if(!m_useNYKZ) return false;
        
        MqlDateTime dt;
        datetime gmtTime = TimeCurrent() - (m_timezoneOffset * 3600);
        TimeToStruct(gmtTime, dt);
        
        return IsTimeInRange(dt.hour, dt.min,
                           m_nyStartHour, m_nyStartMin,
                           m_nyEndHour, m_nyEndMin);
    }
    
    //+------------------------------------------------------------------+
    //| Get current killzone status                                    |
    //+------------------------------------------------------------------+
    string GetKillzoneStatus() {
        bool londonActive = IsInLondonKillzone();
        bool nyActive = IsInNYKillzone();
        
        if(londonActive && nyActive) return "LONDON+NY";
        else if(londonActive) return "LONDON";
        else if(nyActive) return "NY";
        else return "CLOSED";
    }
    
    //+------------------------------------------------------------------+
    //| Get time until next killzone                                   |
    //+------------------------------------------------------------------+
    int GetMinutesToNextKillzone() {
        MqlDateTime dt;
        datetime gmtTime = TimeCurrent() - (m_timezoneOffset * 3600);
        TimeToStruct(gmtTime, dt);
        
        int currentMinutes = dt.hour * 60 + dt.min;
        int londonStart = m_londonStartHour * 60 + m_londonStartMin;
        int londonEnd = m_londonEndHour * 60 + m_londonEndMin;
        int nyStart = m_nyStartHour * 60 + m_nyStartMin;
        int nyEnd = m_nyEndHour * 60 + m_nyEndMin;
        
        // Check if currently in a killzone
        if(IsInKillzone()) return 0;
        
        // Find next killzone start
        int minutesToNext = 1440; // 24 hours in minutes
        
        if(m_useLondonKZ) {
            if(currentMinutes < londonStart) {
                minutesToNext = MathMin(minutesToNext, londonStart - currentMinutes);
            } else {
                minutesToNext = MathMin(minutesToNext, (1440 - currentMinutes) + londonStart);
            }
        }
        
        if(m_useNYKZ) {
            if(currentMinutes < nyStart) {
                minutesToNext = MathMin(minutesToNext, nyStart - currentMinutes);
            } else {
                minutesToNext = MathMin(minutesToNext, (1440 - currentMinutes) + nyStart);
            }
        }
        
        return minutesToNext;
    }
    
    //+------------------------------------------------------------------+
    //| Get killzone quality score (0-100)                            |
    //+------------------------------------------------------------------+
    double GetKillzoneQuality() {
        if(!IsInKillzone()) return 0;
        
        MqlDateTime dt;
        datetime gmtTime = TimeCurrent() - (m_timezoneOffset * 3600);
        TimeToStruct(gmtTime, dt);
        
        double londonQuality = 0;
        double nyQuality = 0;
        
        // Calculate London quality
        if(m_useLondonKZ && IsInLondonKillzone()) {
            londonQuality = CalculateSessionQuality(dt.hour, dt.min,
                                                   m_londonStartHour, m_londonStartMin,
                                                   m_londonEndHour, m_londonEndMin);
        }
        
        // Calculate NY quality
        if(m_useNYKZ && IsInNYKillzone()) {
            nyQuality = CalculateSessionQuality(dt.hour, dt.min,
                                               m_nyStartHour, m_nyStartMin,
                                               m_nyEndHour, m_nyEndMin);
        }
        
        // Return the higher quality score
        return MathMax(londonQuality, nyQuality);
    }
    
    //+------------------------------------------------------------------+
    //| Check if optimal trading time                                  |
    //+------------------------------------------------------------------+
    bool IsOptimalTradingTime() {
        double quality = GetKillzoneQuality();
        return (quality >= 70); // At least 70% quality
    }
    
    //+------------------------------------------------------------------+
    //| Get detailed session info                                      |
    //+------------------------------------------------------------------+
    string GetSessionInfo() {
        MqlDateTime dt;
        datetime gmtTime = TimeCurrent() - (m_timezoneOffset * 3600);
        TimeToStruct(gmtTime, dt);
        
        string info = StringFormat("GMT: %02d:%02d\n", dt.hour, dt.min);
        
        if(m_useLondonKZ) {
            bool londonActive = IsInLondonKillzone();
            info += StringFormat("London (%02d:%02d-%02d:%02d): %s\n",
                               m_londonStartHour, m_londonStartMin,
                               m_londonEndHour, m_londonEndMin,
                               londonActive ? "ACTIVE" : "CLOSED");
        }
        
        if(m_useNYKZ) {
            bool nyActive = IsInNYKillzone();
            info += StringFormat("NY (%02d:%02d-%02d:%02d): %s\n",
                               m_nyStartHour, m_nyStartMin,
                               m_nyEndHour, m_nyEndMin,
                               nyActive ? "ACTIVE" : "CLOSED");
        }
        
        info += "Status: " + GetKillzoneStatus();
        
        if(!IsInKillzone()) {
            int minutesToNext = GetMinutesToNextKillzone();
            int hours = minutesToNext / 60;
            int minutes = minutesToNext % 60;
            info += StringFormat("\nNext: %02d:%02d", hours, minutes);
        }
        
        return info;
    }
    
private:
    //+------------------------------------------------------------------+
    //| Check if time is in range                                      |
    //+------------------------------------------------------------------+
    bool IsTimeInRange(int currentHour, int currentMin, 
                      int startHour, int startMin, 
                      int endHour, int endMin) {
        int currentMinutes = currentHour * 60 + currentMin;
        int startMinutes = startHour * 60 + startMin;
        int endMinutes = endHour * 60 + endMin;
        
        // Handle overnight sessions
        if(endMinutes < startMinutes) {
            return (currentMinutes >= startMinutes || currentMinutes <= endMinutes);
        } else {
            return (currentMinutes >= startMinutes && currentMinutes <= endMinutes);
        }
    }
    
    //+------------------------------------------------------------------+
    //| Calculate session quality based on time within session        |
    //+------------------------------------------------------------------+
    double CalculateSessionQuality(int currentHour, int currentMin,
                                  int startHour, int startMin,
                                  int endHour, int endMin) {
        int currentMinutes = currentHour * 60 + currentMin;
        int startMinutes = startHour * 60 + startMin;
        int endMinutes = endHour * 60 + endMin;
        
        // Calculate session duration
        int sessionDuration;
        if(endMinutes < startMinutes) {
            sessionDuration = (1440 - startMinutes) + endMinutes;
        } else {
            sessionDuration = endMinutes - startMinutes;
        }
        
        // Calculate position within session
        int positionInSession;
        if(endMinutes < startMinutes) {
            if(currentMinutes >= startMinutes) {
                positionInSession = currentMinutes - startMinutes;
            } else {
                positionInSession = (1440 - startMinutes) + currentMinutes;
            }
        } else {
            positionInSession = currentMinutes - startMinutes;
        }
        
        // Calculate quality based on position (peak in middle)
        double sessionProgress = (double)positionInSession / sessionDuration;
        
        // Quality curve: starts at 50%, peaks at 100% in middle, ends at 50%
        double quality;
        if(sessionProgress <= 0.5) {
            quality = 50 + (sessionProgress * 100); // 50% to 100%
        } else {
            quality = 100 - ((sessionProgress - 0.5) * 100); // 100% to 50%
        }
        
        return MathMax(50, MathMin(100, quality));
    }
    
    //+------------------------------------------------------------------+
    //| Check if weekend                                               |
    //+------------------------------------------------------------------+
    bool IsWeekend() {
        MqlDateTime dt;
        TimeToStruct(TimeCurrent(), dt);
        return (dt.day_of_week == 0 || dt.day_of_week == 6); // Sunday or Saturday
    }
    
    //+------------------------------------------------------------------+
    //| Check if market holiday                                        |
    //+------------------------------------------------------------------+
    bool IsMarketHoliday() {
        // Basic holiday check - can be expanded
        MqlDateTime dt;
        TimeToStruct(TimeCurrent(), dt);
        
        // New Year's Day
        if(dt.mon == 1 && dt.day == 1) return true;
        
        // Christmas Day
        if(dt.mon == 12 && dt.day == 25) return true;
        
        // Add more holidays as needed
        return false;
    }
    
    //+------------------------------------------------------------------+
    //| Get session overlap information                                |
    //+------------------------------------------------------------------+
    bool IsSessionOverlap() {
        return (IsInLondonKillzone() && IsInNYKillzone());
    }
    
    //+------------------------------------------------------------------+
    //| Get volatility expectation for current time                   |
    //+------------------------------------------------------------------+
    double GetVolatilityExpectation() {
        if(!IsInKillzone()) return 0.3; // Low volatility outside killzones
        
        if(IsSessionOverlap()) return 1.0; // Highest volatility during overlap
        
        double quality = GetKillzoneQuality();
        return 0.5 + (quality / 100.0 * 0.4); // 50-90% volatility expectation
    }
};

#endif 