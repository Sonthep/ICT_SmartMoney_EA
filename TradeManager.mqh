#ifndef __TRADE_MANAGER_MQH__
#define __TRADE_MANAGER_MQH__

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>

void PlaceEntryOrder(SymbolStatus &status, double lot, ENUM_TIMEFRAMES tf, int slPts, int tpPts, int obBufferPts) {
    CTrade trade;
    double entry, sl, tp;
    
    // ใช้ M5 BOS direction สำหรับ entry
    if(status.isBullishBOS_M5) {
        // Bullish M5 BOS = Buy Order
        entry = SymbolInfoDouble(status.symbol, SYMBOL_ASK);
        
        // SL: ใต้ M5 OB หรือใต้จุด Sweep (5-15 pips)
        double slFromOB = status.obLow_M5 - obBufferPts * _Point;
        double slFromSweep = entry - (obBufferPts + 50) * _Point; // 5-15 pips buffer
        sl = MathMin(slFromOB, slFromSweep); // ใช้ SL ที่ใกล้กว่า
        
        // TP: RR 1:2 หรือ target ถัดไป
        tp = entry + (entry - sl) * 2;
        
        bool result = trade.Buy(lot, status.symbol, entry, sl, tp, "ICT_M5_Buy");
        if(result) {
            Print("[TRADE] BUY order placed - Entry:", entry, " SL:", sl, " TP:", tp);
            Print("SL Distance: ", (entry - sl) / _Point, " points");
        } else {
            Print("[ERROR] Buy order failed. Error: ", GetLastError());
        }
    } else {
        // Bearish M5 BOS = Sell Order  
        entry = SymbolInfoDouble(status.symbol, SYMBOL_BID);
        
        // SL: เหนือ M5 OB หรือเหนือจุด Sweep (5-15 pips)
        double slFromOB = status.obHigh_M5 + obBufferPts * _Point;
        double slFromSweep = entry + (obBufferPts + 50) * _Point; // 5-15 pips buffer
        sl = MathMax(slFromOB, slFromSweep); // ใช้ SL ที่ใกล้กว่า
        
        // TP: RR 1:2 หรือ target ถัดไป
        tp = entry - (sl - entry) * 2;
        
        bool result = trade.Sell(lot, status.symbol, entry, sl, tp, "ICT_M5_Sell");
        if(result) {
            Print("[TRADE] SELL order placed - Entry:", entry, " SL:", sl, " TP:", tp);
            Print("SL Distance: ", (sl - entry) / _Point, " points");
        } else {
            Print("[ERROR] Sell order failed. Error: ", GetLastError());
        }
    }
}

// ฟังก์ชัน Trade Management
void ManageOpenTrades(int trailStartPips = 200, int trailStepPips = 50, int breakEvenPips = 100) {
    CTrade trade;
    CPositionInfo posInfo;
    
    for(int i = PositionsTotal() - 1; i >= 0; i--) {
        if(posInfo.SelectByIndex(i)) {
            string symbol = posInfo.Symbol();
            if(symbol != _Symbol) continue;
            
            double openPrice = posInfo.PriceOpen();
            double currentSL = posInfo.StopLoss();
            double currentTP = posInfo.TakeProfit();
            ulong ticket = posInfo.Ticket();
            ENUM_POSITION_TYPE posType = posInfo.PositionType();
            
            double currentPrice = (posType == POSITION_TYPE_BUY) ? 
                                 SymbolInfoDouble(symbol, SYMBOL_BID) : 
                                 SymbolInfoDouble(symbol, SYMBOL_ASK);
            
            double profit = currentPrice - openPrice;
            if(posType == POSITION_TYPE_SELL) profit = openPrice - currentPrice;
            
            double profitPips = profit / _Point;
            
            // Break Even
            if(profitPips >= breakEvenPips && currentSL != openPrice) {
                double newSL = openPrice;
                if(posType == POSITION_TYPE_SELL) newSL = openPrice;
                
                trade.PositionModify(ticket, newSL, currentTP);
                Print("[TRADE MGT] Break Even activated for ticket: ", ticket);
            }
            
            // Trailing Stop
            if(profitPips >= trailStartPips) {
                double newSL = 0;
                
                if(posType == POSITION_TYPE_BUY) {
                    newSL = currentPrice - trailStepPips * _Point;
                    if(newSL > currentSL) {
                        trade.PositionModify(ticket, newSL, currentTP);
                        Print("[TRADE MGT] Trailing Stop updated for BUY ticket: ", ticket, " New SL: ", newSL);
                    }
                } else {
                    newSL = currentPrice + trailStepPips * _Point;
                    if(newSL < currentSL || currentSL == 0) {
                        trade.PositionModify(ticket, newSL, currentTP);
                        Print("[TRADE MGT] Trailing Stop updated for SELL ticket: ", ticket, " New SL: ", newSL);
                    }
                }
            }
            
            // Partial Close (ปิด 50% เมื่อกำไร 1:1)
            double volume = posInfo.Volume();
            if(profitPips >= 300 && volume > 0.01) { // 300 pips = 1:1 RR
                double closeVolume = NormalizeDouble(volume * 0.5, 2);
                if(closeVolume >= SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN)) {
                    if(posType == POSITION_TYPE_BUY) {
                        trade.Sell(closeVolume, symbol, 0, 0, 0, "Partial_Close_Buy");
                    } else {
                        trade.Buy(closeVolume, symbol, 0, 0, 0, "Partial_Close_Sell");
                    }
                    Print("[TRADE MGT] Partial close 50% for ticket: ", ticket);
                }
            }
        }
    }
}

#endif // __TRADE_MANAGER_MQH__ 