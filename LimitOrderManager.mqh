#ifndef __LIMIT_ORDER_MANAGER_MQH__
#define __LIMIT_ORDER_MANAGER_MQH__

#include <Trade\Trade.mqh>

struct LimitOrderInfo {
    string symbol;
    ENUM_ORDER_TYPE orderType;
    double entryPrice;
    double stopLoss;
    double takeProfit;
    double lotSize;
    string comment;
    int magicNumber;
    datetime expiration;
    bool isActive;
};

class CLimitOrderManager {
private:
    LimitOrderInfo m_orders[];
    CTrade m_trade;
    
public:
    CLimitOrderManager() {
        ArrayResize(m_orders, 0);
    }
    
    // Place Buy Limit at Order Block
    bool PlaceBuyLimit(string symbol, double entryPrice, double obLow, double lotSize, 
                       int slBuffer = 30, double rrRatio = 2.0, string comment = "ICT_BuyLimit") {
        
        // Calculate SL and TP
        double sl = obLow - slBuffer * _Point;
        double slDistance = entryPrice - sl;
        double tp = entryPrice + (slDistance * rrRatio);
        
        // Validate levels
        if(!ValidateOrderLevels(symbol, ORDER_TYPE_BUY_LIMIT, entryPrice, sl, tp)) {
            return false;
        }
        
        // Place order
        bool result = m_trade.BuyLimit(lotSize, entryPrice, symbol, sl, tp, 
                                       ORDER_TIME_DAY, 0, comment);
        
        if(result) {
            Print("[LIMIT ORDER] Buy Limit placed at ", entryPrice, " SL:", sl, " TP:", tp);
            AddOrderToTracking(symbol, ORDER_TYPE_BUY_LIMIT, entryPrice, sl, tp, 
                              lotSize, comment, (int)m_trade.RequestMagic());
        } else {
            Print("[ERROR] Buy Limit failed. Error: ", GetLastError());
        }
        
        return result;
    }
    
    // Place Sell Limit at Order Block
    bool PlaceSellLimit(string symbol, double entryPrice, double obHigh, double lotSize,
                        int slBuffer = 30, double rrRatio = 2.0, string comment = "ICT_SellLimit") {
        
        // Calculate SL and TP
        double sl = obHigh + slBuffer * _Point;
        double slDistance = sl - entryPrice;
        double tp = entryPrice - (slDistance * rrRatio);
        
        // Validate levels
        if(!ValidateOrderLevels(symbol, ORDER_TYPE_SELL_LIMIT, entryPrice, sl, tp)) {
            return false;
        }
        
        // Place order
        bool result = m_trade.SellLimit(lotSize, entryPrice, symbol, sl, tp,
                                        ORDER_TIME_DAY, 0, comment);
        
        if(result) {
            Print("[LIMIT ORDER] Sell Limit placed at ", entryPrice, " SL:", sl, " TP:", tp);
            AddOrderToTracking(symbol, ORDER_TYPE_SELL_LIMIT, entryPrice, sl, tp,
                              lotSize, comment, (int)m_trade.RequestMagic());
        } else {
            Print("[ERROR] Sell Limit failed. Error: ", GetLastError());
        }
        
        return result;
    }
    
    // Validate order levels
    bool ValidateOrderLevels(string symbol, ENUM_ORDER_TYPE orderType, 
                            double entry, double sl, double tp) {
        
        double minStopLevel = SymbolInfoInteger(symbol, SYMBOL_TRADE_STOPS_LEVEL) * _Point;
        double currentPrice = (orderType == ORDER_TYPE_BUY_LIMIT) ? 
                             SymbolInfoDouble(symbol, SYMBOL_ASK) : 
                             SymbolInfoDouble(symbol, SYMBOL_BID);
        
        if(orderType == ORDER_TYPE_BUY_LIMIT) {
            if(entry >= currentPrice) {
                Print("[ERROR] Buy Limit entry must be below current price");
                return false;
            }
            if((entry - sl) < minStopLevel) {
                Print("[ERROR] SL too close to entry. Required: ", minStopLevel/_Point, " points");
                return false;
            }
            if((tp - entry) < minStopLevel) {
                Print("[ERROR] TP too close to entry. Required: ", minStopLevel/_Point, " points");
                return false;
            }
        } else {
            if(entry <= currentPrice) {
                Print("[ERROR] Sell Limit entry must be above current price");
                return false;
            }
            if((sl - entry) < minStopLevel) {
                Print("[ERROR] SL too close to entry. Required: ", minStopLevel/_Point, " points");
                return false;
            }
            if((entry - tp) < minStopLevel) {
                Print("[ERROR] TP too close to entry. Required: ", minStopLevel/_Point, " points");
                return false;
            }
        }
        
        return true;
    }
    
    // Add order to tracking array
    void AddOrderToTracking(string symbol, ENUM_ORDER_TYPE orderType, double entry,
                           double sl, double tp, double lot, string comment, int magic) {
        
        int size = ArraySize(m_orders);
        ArrayResize(m_orders, size + 1);
        
        m_orders[size].symbol = symbol;
        m_orders[size].orderType = orderType;
        m_orders[size].entryPrice = entry;
        m_orders[size].stopLoss = sl;
        m_orders[size].takeProfit = tp;
        m_orders[size].lotSize = lot;
        m_orders[size].comment = comment;
        m_orders[size].magicNumber = magic;
        m_orders[size].expiration = TimeCurrent() + 86400; // 24 hours
        m_orders[size].isActive = true;
    }
    
    // Check and manage pending orders
    void ManagePendingOrders() {
        for(int i = ArraySize(m_orders) - 1; i >= 0; i--) {
            if(!m_orders[i].isActive) continue;
            
            // Check if order still exists
            if(!OrderExists(m_orders[i].symbol, m_orders[i].orderType, m_orders[i].entryPrice)) {
                m_orders[i].isActive = false;
                Print("[ORDER] Order executed or cancelled: ", m_orders[i].comment);
                continue;
            }
            
            // Check expiration
            if(TimeCurrent() > m_orders[i].expiration) {
                CancelOrder(m_orders[i].symbol, m_orders[i].orderType, m_orders[i].entryPrice);
                m_orders[i].isActive = false;
                Print("[ORDER] Order expired and cancelled: ", m_orders[i].comment);
            }
        }
    }
    
    // Check if order exists
    bool OrderExists(string symbol, ENUM_ORDER_TYPE orderType, double entryPrice) {
        for(int i = 0; i < OrdersTotal(); i++) {
            if(OrderSelect(OrderGetTicket(i))) {
                if(OrderGetString(ORDER_SYMBOL) == symbol &&
                   OrderGetInteger(ORDER_TYPE) == orderType &&
                   MathAbs(OrderGetDouble(ORDER_PRICE_OPEN) - entryPrice) < _Point) {
                    return true;
                }
            }
        }
        return false;
    }
    
    // Cancel specific order
    bool CancelOrder(string symbol, ENUM_ORDER_TYPE orderType, double entryPrice) {
        for(int i = 0; i < OrdersTotal(); i++) {
            ulong ticket = OrderGetTicket(i);
            if(OrderSelect(ticket)) {
                if(OrderGetString(ORDER_SYMBOL) == symbol &&
                   OrderGetInteger(ORDER_TYPE) == orderType &&
                   MathAbs(OrderGetDouble(ORDER_PRICE_OPEN) - entryPrice) < _Point) {
                    return m_trade.OrderDelete(ticket);
                }
            }
        }
        return false;
    }
    
    // Get active orders count for symbol
    int GetActiveOrdersCount(string symbol) {
        int count = 0;
        for(int i = 0; i < ArraySize(m_orders); i++) {
            if(m_orders[i].isActive && m_orders[i].symbol == symbol) {
                count++;
            }
        }
        return count;
    }
};

#endif // __LIMIT_ORDER_MANAGER_MQH__ 