#ifndef __PARTIAL_TP_MANAGER_MQH__
#define __PARTIAL_TP_MANAGER_MQH__

#include <Trade\Trade.mqh>

struct PartialTPInfo {
    ulong positionTicket;
    string symbol;
    double entryPrice;
    double stopLoss;
    double takeProfit1;  // 1:1 RR
    double takeProfit2;  // 1:2 RR
    double originalLot;
    bool firstTPHit;
    bool isActive;
    datetime entryTime;
};

class CPartialTPManager {
private:
    PartialTPInfo m_positions[];
    CTrade m_trade;
    
public:
    CPartialTPManager() {
        ArrayResize(m_positions, 0);
    }
    
    // Add position for partial TP management
    void AddPosition(ulong ticket, string symbol, double entry, double sl, 
                    double tp1, double tp2, double lot) {
        
        int size = ArraySize(m_positions);
        ArrayResize(m_positions, size + 1);
        
        m_positions[size].positionTicket = ticket;
        m_positions[size].symbol = symbol;
        m_positions[size].entryPrice = entry;
        m_positions[size].stopLoss = sl;
        m_positions[size].takeProfit1 = tp1;
        m_positions[size].takeProfit2 = tp2;
        m_positions[size].originalLot = lot;
        m_positions[size].firstTPHit = false;
        m_positions[size].isActive = true;
        m_positions[size].entryTime = TimeCurrent();
        
        Print("[PARTIAL TP] Position added for management: ", ticket);
    }
    
    // Check and manage partial TPs
    void ManagePartialTPs() {
        for(int i = ArraySize(m_positions) - 1; i >= 0; i--) {
            if(!m_positions[i].isActive) continue;
            
            // Check if position still exists
            if(!PositionSelectByTicket(m_positions[i].positionTicket)) {
                m_positions[i].isActive = false;
                Print("[PARTIAL TP] Position closed: ", m_positions[i].positionTicket);
                continue;
            }
            
            double currentPrice = PositionGetDouble(POSITION_PRICE_CURRENT);
            double currentLot = PositionGetDouble(POSITION_VOLUME);
            ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
            
            // Check for first TP (1:1 RR)
            if(!m_positions[i].firstTPHit) {
                bool tp1Hit = false;
                
                if(posType == POSITION_TYPE_BUY) {
                    tp1Hit = (currentPrice >= m_positions[i].takeProfit1);
                } else {
                    tp1Hit = (currentPrice <= m_positions[i].takeProfit1);
                }
                
                if(tp1Hit) {
                    ExecutePartialClose(i, 0.5); // Close 50%
                    MoveToBreakeven(i);
                }
            }
            
            // Check for second TP (1:2 RR)
            if(m_positions[i].firstTPHit) {
                bool tp2Hit = false;
                
                if(posType == POSITION_TYPE_BUY) {
                    tp2Hit = (currentPrice >= m_positions[i].takeProfit2);
                } else {
                    tp2Hit = (currentPrice <= m_positions[i].takeProfit2);
                }
                
                if(tp2Hit) {
                    // Close remaining position
                    if(m_trade.PositionClose(m_positions[i].positionTicket)) {
                        Print("[PARTIAL TP] Final TP hit, position fully closed: ", m_positions[i].positionTicket);
                        m_positions[i].isActive = false;
                    }
                }
            }
        }
    }
    
    // Execute partial close
    void ExecutePartialClose(int index, double percentage) {
        if(index < 0 || index >= ArraySize(m_positions)) return;
        
        double currentLot = PositionGetDouble(POSITION_VOLUME);
        double closeVolume = NormalizeDouble(currentLot * percentage, 2);
        
        // Ensure minimum lot size
        double minLot = SymbolInfoDouble(m_positions[index].symbol, SYMBOL_VOLUME_MIN);
        if(closeVolume < minLot) {
            closeVolume = minLot;
        }
        
        // Ensure we don't close more than available
        if(closeVolume >= currentLot) {
            closeVolume = currentLot;
        }
        
        bool result = m_trade.PositionClosePartial(m_positions[index].positionTicket, closeVolume);
        
        if(result) {
            m_positions[index].firstTPHit = true;
            Print("[PARTIAL TP] Partial close executed: ", closeVolume, " lots at 1:1 RR");
        } else {
            Print("[ERROR] Partial close failed: ", GetLastError());
        }
    }
    
    // Move SL to breakeven
    void MoveToBreakeven(int index) {
        if(index < 0 || index >= ArraySize(m_positions)) return;
        
        double newSL = m_positions[index].entryPrice;
        
        // Add small buffer to avoid immediate stop out
        ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
        double buffer = 5 * _Point; // 0.5 pips buffer
        
        if(posType == POSITION_TYPE_BUY) {
            newSL += buffer;
        } else {
            newSL -= buffer;
        }
        
        bool result = m_trade.PositionModify(m_positions[index].positionTicket, 
                                           newSL, 
                                           m_positions[index].takeProfit2);
        
        if(result) {
            m_positions[index].stopLoss = newSL;
            Print("[PARTIAL TP] SL moved to breakeven + buffer: ", newSL);
        } else {
            Print("[ERROR] Failed to move SL to breakeven: ", GetLastError());
        }
    }
    
    // Get position info for display
    string GetPositionInfo(string symbol) {
        for(int i = 0; i < ArraySize(m_positions); i++) {
            if(m_positions[i].isActive && m_positions[i].symbol == symbol) {
                
                if(!PositionSelectByTicket(m_positions[i].positionTicket)) continue;
                
                double currentPrice = PositionGetDouble(POSITION_PRICE_CURRENT);
                double unrealizedPL = PositionGetDouble(POSITION_PROFIT);
                ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
                
                // Calculate current RR
                double priceDiff = MathAbs(currentPrice - m_positions[i].entryPrice);
                double slDiff = MathAbs(m_positions[i].entryPrice - m_positions[i].stopLoss);
                double currentRR = (slDiff > 0) ? priceDiff / slDiff : 0;
                
                string status = m_positions[i].firstTPHit ? "TP1 Hit" : "Active";
                
                return StringFormat("Pos: %s | RR: %.2f | P/L: %.2f | %s", 
                                  (posType == POSITION_TYPE_BUY) ? "BUY" : "SELL",
                                  currentRR, unrealizedPL, status);
            }
        }
        return "No Active Position";
    }
    
    // Check if symbol has active position
    bool HasActivePosition(string symbol) {
        for(int i = 0; i < ArraySize(m_positions); i++) {
            if(m_positions[i].isActive && m_positions[i].symbol == symbol) {
                return PositionSelectByTicket(m_positions[i].positionTicket);
            }
        }
        return false;
    }
    
    // Clean up inactive positions
    void CleanupInactivePositions() {
        for(int i = ArraySize(m_positions) - 1; i >= 0; i--) {
            if(!m_positions[i].isActive) {
                // Remove from array
                for(int j = i; j < ArraySize(m_positions) - 1; j++) {
                    m_positions[j] = m_positions[j + 1];
                }
                ArrayResize(m_positions, ArraySize(m_positions) - 1);
            }
        }
    }
};

#endif // __PARTIAL_TP_MANAGER_MQH__ 