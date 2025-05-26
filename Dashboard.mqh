//+------------------------------------------------------------------+
//| Dashboard.mqh                                                    |
//| Visual Dashboard for ICT Smart Money EA                         |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024 - ICT Smart Money EA"
#property version   "1.00"

#include "Structures.mqh"

//+------------------------------------------------------------------+
//| Dashboard Class                                                  |
//+------------------------------------------------------------------+
class CDashboard {
private:
    string m_symbol;
    int m_xOffset;
    int m_yOffset;
    int m_lineHeight;
    color m_textColor;
    color m_bgColor;
    int m_fontSize;
    string m_fontName;
    
    // Dashboard elements
    string m_labelPrefix;
    
public:
    CDashboard();
    ~CDashboard();
    
    void Initialize(string symbol);
    void Update(DailyTradeData &dailyData, SignalData &signalData);
    void SetPosition(int x, int y);
    void SetColors(color textColor, color bgColor);
    void SetFont(string fontName, int fontSize);
    void Clear();
    
private:
    void CreateLabel(string name, string text, int x, int y, color clr = clrWhite);
    void UpdateLabel(string name, string text, color clr = clrWhite);
    string FormatTime(datetime time);
    string GetSessionStatus();
    color GetConfidenceColor(double score);
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CDashboard::CDashboard() {
    m_symbol = "";
    m_xOffset = 20;
    m_yOffset = 50;
    m_lineHeight = 18;
    m_textColor = clrWhite;
    m_bgColor = clrDarkBlue;
    m_fontSize = 9;
    m_fontName = "Consolas";
    m_labelPrefix = "ICT_Dashboard_";
}

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CDashboard::~CDashboard() {
    Clear();
}

//+------------------------------------------------------------------+
//| Initialize Dashboard                                             |
//+------------------------------------------------------------------+
void CDashboard::Initialize(string symbol) {
    m_symbol = symbol;
    Clear();
    
    // Create background
    string bgName = m_labelPrefix + "Background";
    ObjectCreate(0, bgName, OBJ_RECTANGLE_LABEL, 0, 0, 0);
    ObjectSetInteger(0, bgName, OBJPROP_XDISTANCE, m_xOffset - 5);
    ObjectSetInteger(0, bgName, OBJPROP_YDISTANCE, m_yOffset - 5);
    ObjectSetInteger(0, bgName, OBJPROP_XSIZE, 300);
    ObjectSetInteger(0, bgName, OBJPROP_YSIZE, 280);
    ObjectSetInteger(0, bgName, OBJPROP_COLOR, m_bgColor);
    ObjectSetInteger(0, bgName, OBJPROP_BGCOLOR, m_bgColor);
    ObjectSetInteger(0, bgName, OBJPROP_BORDER_TYPE, BORDER_FLAT);
    ObjectSetInteger(0, bgName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
    ObjectSetInteger(0, bgName, OBJPROP_STYLE, STYLE_SOLID);
    ObjectSetInteger(0, bgName, OBJPROP_WIDTH, 1);
    ObjectSetInteger(0, bgName, OBJPROP_BACK, true);
    
    // Create header
    CreateLabel("Header", "=== ICT Smart Money EA v4.0 ===", m_xOffset, m_yOffset, clrYellow);
    CreateLabel("Symbol", "Symbol: " + m_symbol, m_xOffset, m_yOffset + m_lineHeight, clrLightBlue);
    
    Print("[DASHBOARD] Initialized for ", m_symbol);
}

//+------------------------------------------------------------------+
//| Update Dashboard                                                 |
//+------------------------------------------------------------------+
void CDashboard::Update(DailyTradeData &dailyData, SignalData &signalData) {
    int yPos = m_yOffset + (m_lineHeight * 3);
    
    // Session Information
    UpdateLabel("SessionHeader", "=== SESSION INFO ===", clrYellow);
    ObjectSetInteger(0, m_labelPrefix + "SessionHeader", OBJPROP_YDISTANCE, yPos);
    yPos += m_lineHeight;
    
    string sessionStatus = GetSessionStatus();
    UpdateLabel("SessionStatus", "Status: " + sessionStatus, clrLightGreen);
    ObjectSetInteger(0, m_labelPrefix + "SessionStatus", OBJPROP_YDISTANCE, yPos);
    yPos += m_lineHeight;
    
    UpdateLabel("CurrentTime", "Time: " + FormatTime(TimeCurrent()), clrWhite);
    ObjectSetInteger(0, m_labelPrefix + "CurrentTime", OBJPROP_YDISTANCE, yPos);
    yPos += m_lineHeight * 1.5;
    
    // Daily Statistics
    UpdateLabel("DailyHeader", "=== DAILY STATS ===", clrYellow);
    ObjectSetInteger(0, m_labelPrefix + "DailyHeader", OBJPROP_YDISTANCE, yPos);
    yPos += m_lineHeight;
    
    UpdateLabel("TradesCount", StringFormat("Trades: %d/2", dailyData.tradesCount), 
                dailyData.tradesCount >= 2 ? clrOrange : clrWhite);
    ObjectSetInteger(0, m_labelPrefix + "TradesCount", OBJPROP_YDISTANCE, yPos);
    yPos += m_lineHeight;
    
    color profitColor = (dailyData.totalProfit > 0) ? clrLimeGreen : 
                       (dailyData.totalProfit < 0) ? clrRed : clrWhite;
    UpdateLabel("DailyProfit", StringFormat("P/L: %.2f", dailyData.totalProfit), profitColor);
    ObjectSetInteger(0, m_labelPrefix + "DailyProfit", OBJPROP_YDISTANCE, yPos);
    yPos += m_lineHeight;
    
    if(dailyData.wins + dailyData.losses > 0) {
        double winRate = (double)dailyData.wins / (dailyData.wins + dailyData.losses) * 100;
        UpdateLabel("WinRate", StringFormat("Win Rate: %.1f%% (%d/%d)", winRate, dailyData.wins, dailyData.wins + dailyData.losses), 
                    winRate >= 70 ? clrLimeGreen : winRate >= 50 ? clrYellow : clrRed);
        ObjectSetInteger(0, m_labelPrefix + "WinRate", OBJPROP_YDISTANCE, yPos);
    } else {
        UpdateLabel("WinRate", "Win Rate: N/A", clrGray);
        ObjectSetInteger(0, m_labelPrefix + "WinRate", OBJPROP_YDISTANCE, yPos);
    }
    yPos += m_lineHeight * 1.5;
    
    // Current Signal Information
    UpdateLabel("SignalHeader", "=== CURRENT SIGNAL ===", clrYellow);
    ObjectSetInteger(0, m_labelPrefix + "SignalHeader", OBJPROP_YDISTANCE, yPos);
    yPos += m_lineHeight;
    
    if(signalData.confidenceScore > 0) {
        color scoreColor = GetConfidenceColor(signalData.confidenceScore);
        UpdateLabel("ConfidenceScore", StringFormat("Confidence: %.0f/100", signalData.confidenceScore), scoreColor);
        ObjectSetInteger(0, m_labelPrefix + "ConfidenceScore", OBJPROP_YDISTANCE, yPos);
        yPos += m_lineHeight;
        
        string direction = signalData.isBullish ? "BULLISH" : "BEARISH";
        color dirColor = signalData.isBullish ? clrLimeGreen : clrRed;
        UpdateLabel("Direction", "Direction: " + direction, dirColor);
        ObjectSetInteger(0, m_labelPrefix + "Direction", OBJPROP_YDISTANCE, yPos);
        yPos += m_lineHeight;
        
        // Signal components
        string components = "";
        if(signalData.sweepDetected) components += "✓Sweep ";
        if(signalData.bosDetected) components += "✓BOS ";
        if(signalData.obFound) components += "✓OB ";
        if(signalData.fvgFound) components += "✓FVG ";
        
        UpdateLabel("Components", "Setup: " + components, clrLightBlue);
        ObjectSetInteger(0, m_labelPrefix + "Components", OBJPROP_YDISTANCE, yPos);
        yPos += m_lineHeight;
        
        if(signalData.obFound) {
            UpdateLabel("OBLevel", StringFormat("OB: %.5f - %.5f", signalData.obLow, signalData.obHigh), clrCyan);
            ObjectSetInteger(0, m_labelPrefix + "OBLevel", OBJPROP_YDISTANCE, yPos);
            yPos += m_lineHeight;
        }
        
        UpdateLabel("SignalTime", "Time: " + FormatTime(signalData.signalTime), clrWhite);
        ObjectSetInteger(0, m_labelPrefix + "SignalTime", OBJPROP_YDISTANCE, yPos);
    } else {
        UpdateLabel("ConfidenceScore", "Confidence: Scanning...", clrGray);
        ObjectSetInteger(0, m_labelPrefix + "ConfidenceScore", OBJPROP_YDISTANCE, yPos);
        yPos += m_lineHeight;
        
        UpdateLabel("Direction", "Direction: N/A", clrGray);
        ObjectSetInteger(0, m_labelPrefix + "Direction", OBJPROP_YDISTANCE, yPos);
        yPos += m_lineHeight;
        
        UpdateLabel("Components", "Setup: Waiting for signal...", clrGray);
        ObjectSetInteger(0, m_labelPrefix + "Components", OBJPROP_YDISTANCE, yPos);
    }
    
    ChartRedraw();
}

//+------------------------------------------------------------------+
//| Set Dashboard Position                                           |
//+------------------------------------------------------------------+
void CDashboard::SetPosition(int x, int y) {
    m_xOffset = x;
    m_yOffset = y;
}

//+------------------------------------------------------------------+
//| Set Dashboard Colors                                             |
//+------------------------------------------------------------------+
void CDashboard::SetColors(color textColor, color bgColor) {
    m_textColor = textColor;
    m_bgColor = bgColor;
}

//+------------------------------------------------------------------+
//| Set Dashboard Font                                               |
//+------------------------------------------------------------------+
void CDashboard::SetFont(string fontName, int fontSize) {
    m_fontName = fontName;
    m_fontSize = fontSize;
}

//+------------------------------------------------------------------+
//| Clear Dashboard                                                  |
//+------------------------------------------------------------------+
void CDashboard::Clear() {
    ObjectsDeleteAll(0, m_labelPrefix);
}

//+------------------------------------------------------------------+
//| Create Label                                                     |
//+------------------------------------------------------------------+
void CDashboard::CreateLabel(string name, string text, int x, int y, color clr = clrWhite) {
    string fullName = m_labelPrefix + name;
    
    ObjectCreate(0, fullName, OBJ_LABEL, 0, 0, 0);
    ObjectSetInteger(0, fullName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
    ObjectSetInteger(0, fullName, OBJPROP_XDISTANCE, x);
    ObjectSetInteger(0, fullName, OBJPROP_YDISTANCE, y);
    ObjectSetInteger(0, fullName, OBJPROP_COLOR, clr);
    ObjectSetInteger(0, fullName, OBJPROP_FONTSIZE, m_fontSize);
    ObjectSetString(0, fullName, OBJPROP_FONT, m_fontName);
    ObjectSetString(0, fullName, OBJPROP_TEXT, text);
    ObjectSetInteger(0, fullName, OBJPROP_SELECTABLE, false);
    ObjectSetInteger(0, fullName, OBJPROP_SELECTED, false);
}

//+------------------------------------------------------------------+
//| Update Label                                                     |
//+------------------------------------------------------------------+
void CDashboard::UpdateLabel(string name, string text, color clr = clrWhite) {
    string fullName = m_labelPrefix + name;
    
    if(ObjectFind(0, fullName) < 0) {
        CreateLabel(name, text, m_xOffset, m_yOffset, clr);
    } else {
        ObjectSetString(0, fullName, OBJPROP_TEXT, text);
        ObjectSetInteger(0, fullName, OBJPROP_COLOR, clr);
    }
}

//+------------------------------------------------------------------+
//| Format Time                                                      |
//+------------------------------------------------------------------+
string CDashboard::FormatTime(datetime time) {
    return TimeToString(time, TIME_DATE | TIME_MINUTES);
}

//+------------------------------------------------------------------+
//| Get Session Status                                               |
//+------------------------------------------------------------------+
string CDashboard::GetSessionStatus() {
    MqlDateTime dt;
    TimeToStruct(TimeCurrent(), dt);
    int currentHour = dt.hour;
    
    // London Session: 08:00-10:30 GMT
    if(currentHour >= 8 && currentHour < 11) {
        return "London Killzone";
    }
    // NY Session: 13:00-16:00 GMT  
    else if(currentHour >= 13 && currentHour < 16) {
        return "NY Killzone";
    }
    else {
        return "Outside Killzone";
    }
}

//+------------------------------------------------------------------+
//| Get Confidence Color                                             |
//+------------------------------------------------------------------+
color CDashboard::GetConfidenceColor(double score) {
    if(score >= 90) return clrLimeGreen;
    else if(score >= 85) return clrYellow;
    else if(score >= 70) return clrOrange;
    else return clrRed;
} 