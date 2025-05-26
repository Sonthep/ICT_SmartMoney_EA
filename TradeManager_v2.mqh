//+------------------------------------------------------------------+
//| TradeManager_v2.mqh                                             |
//| Advanced Trade Management for ICT Smart Money EA               |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024 - ICT Smart Money EA"
#property version   "2.00"

#include <Trade\Trade.mqh>

//+------------------------------------------------------------------+
//| Trade Management Structure                                       |
//+------------------------------------------------------------------+
struct TradeInfo {
    ulong ticket;
    double entryPrice;
    double originalSL;
    double originalTP;
    bool breakEvenSet;
    bool trailingActive;
    datetime openTime;
};

//+------------------------------------------------------------------+
//| CTradeManager_v2 Class                                          |
//+------------------------------------------------------------------+
class CTradeManager_v2 {
private:
    bool m_enableBreakEven;
    bool m_enableTrailing;
    ulong m_magicNumber;
    
    TradeInfo m_trades[];
    CTrade m_trade;
    
    // Break-even settings
    double m_breakEvenTrigger;  // Points to trigger break-even
    double m_breakEvenOffset;   // Points above/below entry for BE
    
    // Trailing settings
    double m_trailingStart;     // Points profit to start trailing
    double m_trailingStep;      // Points to trail by
    double m_trailingStop;      // Minimum trailing distance
    
public:
    CTradeManager_v2();
    ~CTradeManager_v2();
    
    void SetParameters(bool enableBE, bool enableTrailing, ulong magic);
    void SetBreakEvenSettings(double trigger = 200, double offset = 50);
    void SetTrailingSettings(double start = 300, double step = 100, double stop = 150);
    
    void AddTrade(ulong ticket, double entry, double sl, double tp);
    void ManageTrades();
    void RemoveTrade(ulong ticket);
    void ClearAllTrades();
    
private:
    int FindTradeIndex(ulong ticket);
    bool IsTradeOpen(ulong ticket);
    void ManageBreakEven(TradeInfo &trade);
    void ManageTrailing(TradeInfo &trade);
    double GetCurrentPrice(string symbol, bool isBuy);
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CTradeManager_v2::CTradeManager_v2() {
    m_enableBreakEven = true;
    m_enableTrailing = true;
    m_magicNumber = 0;
    
    // Default settings
    SetBreakEvenSettings();
    SetTrailingSettings();
    
    ArrayResize(m_trades, 0);
}

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CTradeManager_v2::~CTradeManager_v2() {
    ArrayFree(m_trades);
}

//+------------------------------------------------------------------+
//| Set Parameters                                                   |
//+------------------------------------------------------------------+
void CTradeManager_v2::SetParameters(bool enableBE, bool enableTrailing, ulong magic) {
    m_enableBreakEven = enableBE;
    m_enableTrailing = enableTrailing;
    m_magicNumber = magic;
    m_trade.SetExpertMagicNumber(magic);
}

//+------------------------------------------------------------------+
//| Set Break-Even Settings                                         |
//+------------------------------------------------------------------+
void CTradeManager_v2::SetBreakEvenSettings(double trigger = 200, double offset = 50) {
    m_breakEvenTrigger = trigger;
    m_breakEvenOffset = offset;
}

//+------------------------------------------------------------------+
//| Set Trailing Settings                                           |
//+------------------------------------------------------------------+
void CTradeManager_v2::SetTrailingSettings(double start = 300, double step = 100, double stop = 150) {
    m_trailingStart = start;
    m_trailingStep = step;
    m_trailingStop = stop;
}

//+------------------------------------------------------------------+
//| Add Trade to Management                                         |
//+------------------------------------------------------------------+
void CTradeManager_v2::AddTrade(ulong ticket, double entry, double sl, double tp) {
    if(ticket == 0) return;
    
    // Check if trade already exists
    if(FindTradeIndex(ticket) >= 0) return;
    
    // Add new trade
    int size = ArraySize(m_trades);
    ArrayResize(m_trades, size + 1);
    
    m_trades[size].ticket = ticket;
    m_trades[size].entryPrice = entry;
    m_trades[size].originalSL = sl;
    m_trades[size].originalTP = tp;
    m_trades[size].breakEvenSet = false;
    m_trades[size].trailingActive = false;
    m_trades[size].openTime = TimeCurrent();
    
    Print("[TRADE_MGR] Added trade #", ticket, " to management");
}

//+------------------------------------------------------------------+
//| Manage All Trades                                               |
//+------------------------------------------------------------------+
void CTradeManager_v2::ManageTrades() {
    for(int i = ArraySize(m_trades) - 1; i >= 0; i--) {
        if(!IsTradeOpen(m_trades[i].ticket)) {
            // Remove closed trade
            for(int j = i; j < ArraySize(m_trades) - 1; j++) {
                m_trades[j] = m_trades[j + 1];
            }
            ArrayResize(m_trades, ArraySize(m_trades) - 1);
            continue;
        }
        
        // Manage break-even
        if(m_enableBreakEven && !m_trades[i].breakEvenSet) {
            ManageBreakEven(m_trades[i]);
        }
        
        // Manage trailing stop
        if(m_enableTrailing) {
            ManageTrailing(m_trades[i]);
        }
    }
}

//+------------------------------------------------------------------+
//| Remove Trade from Management                                    |
//+------------------------------------------------------------------+
void CTradeManager_v2::RemoveTrade(ulong ticket) {
    int index = FindTradeIndex(ticket);
    if(index < 0) return;
    
    for(int i = index; i < ArraySize(m_trades) - 1; i++) {
        m_trades[i] = m_trades[i + 1];
    }
    ArrayResize(m_trades, ArraySize(m_trades) - 1);
}

//+------------------------------------------------------------------+
//| Clear All Trades                                               |
//+------------------------------------------------------------------+
void CTradeManager_v2::ClearAllTrades() {
    ArrayResize(m_trades, 0);
}

//+------------------------------------------------------------------+
//| Find Trade Index                                                |
//+------------------------------------------------------------------+
int CTradeManager_v2::FindTradeIndex(ulong ticket) {
    for(int i = 0; i < ArraySize(m_trades); i++) {
        if(m_trades[i].ticket == ticket) {
            return i;
        }
    }
    return -1;
}

//+------------------------------------------------------------------+
//| Check if Trade is Open                                          |
//+------------------------------------------------------------------+
bool CTradeManager_v2::IsTradeOpen(ulong ticket) {
    return PositionSelectByTicket(ticket);
}

//+------------------------------------------------------------------+
//| Manage Break-Even                                               |
//+------------------------------------------------------------------+
void CTradeManager_v2::ManageBreakEven(TradeInfo &trade) {
    if(!PositionSelectByTicket(trade.ticket)) return;
    
    string symbol = PositionGetString(POSITION_SYMBOL);
    double currentPrice = GetCurrentPrice(symbol, PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);
    bool isBuy = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);
    
    double profitPoints;
    if(isBuy) {
        profitPoints = (currentPrice - trade.entryPrice) / _Point;
    } else {
        profitPoints = (trade.entryPrice - currentPrice) / _Point;
    }
    
    // Check if profit is enough to trigger break-even
    if(profitPoints >= m_breakEvenTrigger) {
        double newSL;
        if(isBuy) {
            newSL = trade.entryPrice + (m_breakEvenOffset * _Point);
        } else {
            newSL = trade.entryPrice - (m_breakEvenOffset * _Point);
        }
        
        // Modify stop loss to break-even
        if(m_trade.PositionModify(trade.ticket, newSL, PositionGetDouble(POSITION_TP))) {
            trade.breakEvenSet = true;
            Print("[BREAK_EVEN] Trade #", trade.ticket, " moved to break-even at ", newSL);
        }
    }
}

//+------------------------------------------------------------------+
//| Manage Trailing Stop                                           |
//+------------------------------------------------------------------+
void CTradeManager_v2::ManageTrailing(TradeInfo &trade) {
    if(!PositionSelectByTicket(trade.ticket)) return;
    
    string symbol = PositionGetString(POSITION_SYMBOL);
    double currentPrice = GetCurrentPrice(symbol, PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);
    bool isBuy = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);
    double currentSL = PositionGetDouble(POSITION_SL);
    
    double profitPoints;
    if(isBuy) {
        profitPoints = (currentPrice - trade.entryPrice) / _Point;
    } else {
        profitPoints = (trade.entryPrice - currentPrice) / _Point;
    }
    
    // Check if profit is enough to start trailing
    if(profitPoints >= m_trailingStart) {
        double newSL;
        
        if(isBuy) {
            newSL = currentPrice - (m_trailingStop * _Point);
            // Only move SL up
            if(newSL > currentSL + (m_trailingStep * _Point)) {
                if(m_trade.PositionModify(trade.ticket, newSL, PositionGetDouble(POSITION_TP))) {
                    trade.trailingActive = true;
                    Print("[TRAILING] Trade #", trade.ticket, " SL moved to ", newSL);
                }
            }
        } else {
            newSL = currentPrice + (m_trailingStop * _Point);
            // Only move SL down
            if(newSL < currentSL - (m_trailingStep * _Point)) {
                if(m_trade.PositionModify(trade.ticket, newSL, PositionGetDouble(POSITION_TP))) {
                    trade.trailingActive = true;
                    Print("[TRAILING] Trade #", trade.ticket, " SL moved to ", newSL);
                }
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Get Current Price                                               |
//+------------------------------------------------------------------+
double CTradeManager_v2::GetCurrentPrice(string symbol, bool isBuy) {
    MqlTick tick;
    if(!SymbolInfoTick(symbol, tick)) return 0;
    
    return isBuy ? tick.bid : tick.ask;
} 