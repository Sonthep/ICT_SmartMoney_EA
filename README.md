# 📖 ICT Multi-Timeframe Expert Advisor Documentation

## 📋 **Table of Contents**
1. [Overview](#overview)
2. [Strategy Logic](#strategy-logic)
3. [Installation Guide](#installation-guide)
4. [Parameters Configuration](#parameters-configuration)
5. [Trading Rules](#trading-rules)
6. [Risk Management](#risk-management)
7. [Performance Monitoring](#performance-monitoring)
8. [Troubleshooting](#troubleshooting)
9. [Best Practices](#best-practices)

---

## 🎯 **Overview**

### **EA Name:** ICT Multi-Timeframe Expert Advisor
### **Version:** 2.00
### **Strategy:** Inner Circle Trader (ICT) Concepts
### **Timeframes:** M15 (Filter) + M5 (Entry)
### **Instruments:** All Forex Pairs (Recommended: Major Pairs)

### **Key Features:**
- ✅ Multi-timeframe analysis (M15 + M5)
- ✅ ICT concepts: BOS, Order Blocks, Sweeps
- ✅ Session-based trading (London + NY)
- ✅ Advanced risk management
- ✅ Real-time statistics panel
- ✅ Visual chart elements

---

## 🧠 **Strategy Logic**

### **Phase 1: M15 Filter Analysis**
The EA first analyzes the M15 timeframe to identify high-probability setups:

1. **Break of Structure (BOS):** Price breaks previous high/low within lookback period
2. **Order Block (OB):** Identifies the last opposite candle before BOS
3. **Liquidity Sweep:** Price breaks previous candle's high/low
4. **Price Return:** Price returns to the identified Order Block zone

### **Phase 2: M5 Entry Confirmation**
Once M15 filter passes, the EA analyzes M5 for precise entry:

1. **Directional Sweep:** M5 sweep in same direction as M15 BOS
2. **Confirming BOS:** M5 BOS in same direction as M15
3. **New Order Block:** Fresh M5 Order Block for entry
4. **Entry Signal:** All conditions met = Market Order

### **Multi-Timeframe Flow:**
```
M15 Analysis → Filter Pass → M5 Analysis → Entry Signal → Trade Execution
```

---

## 💾 **Installation Guide**

### **Step 1: File Structure**
Place the following files in your MT5 `MQL5/Experts/` folder:
```
📁 Experts/
├── 📄 ICT_EA_Core.mq5 (Main EA file)
├── 📄 SessionUtils.mqh
├── 📄 RiskManager.mqh
├── 📄 OB_BOS_Scan.mqh
├── 📄 TradeManager.mqh
└── 📄 DrawUtils.mqh
```

### **Step 2: Compilation**
1. Open MetaEditor (F4 in MT5)
2. Open `ICT_EA_Core.mq5`
3. Click Compile (F7)
4. Ensure no errors in compilation

### **Step 3: Attachment**
1. Drag EA from Navigator to chart
2. Configure parameters (see below)
3. Enable AutoTrading
4. Click OK

---

## ⚙️ **Parameters Configuration**

### **Core ICT Parameters**
| Parameter | Default | Description | Range |
|-----------|---------|-------------|-------|
| `RiskPercent` | 1.0 | Risk per trade (% of account) | 0.1 - 5.0 |
| `BOS_Lookback` | 10 | Candles to check for BOS | 5 - 20 |
| `OB_Buffer_Points` | 30 | SL buffer from OB (points) | 10 - 100 |
| `MaxTradesPerDay` | 2 | Daily trade limit per symbol | 1 - 10 |

### **Session Parameters**
| Parameter | Default | Description |
|-----------|---------|-------------|
| `London_KZ` | "08:00–17:00" | London session time |
| `NY_KZ` | "09:30–16:00" | New York session time |
| `GMT_Offset` | 0 | Broker timezone offset |

### **Optional Features**
| Parameter | Default | Description |
|-----------|---------|-------------|
| `EnableTradeManagement` | true | Break Even + Trailing Stop |
| `ShowStats` | true | Display statistics panel |

---

## 📊 **Trading Rules**

### **Entry Conditions (ALL must be met):**

#### **M15 Filter Requirements:**
1. ✅ **BOS Detected:** Current candle breaks previous high/low
2. ✅ **Order Block Found:** Opposite candle before BOS identified
3. ✅ **Sweep Occurred:** Price breaks previous candle's high/low
4. ✅ **Price Return:** Current price is within OB zone
5. ✅ **Session Active:** London or NY session is active

#### **M5 Entry Requirements:**
1. ✅ **Directional Sweep:** M5 sweep matches M15 BOS direction
2. ✅ **Confirming BOS:** M5 BOS in same direction as M15
3. ✅ **Fresh Order Block:** New M5 OB identified
4. ✅ **Same Direction:** M5 and M15 BOS alignment
5. ✅ **New Bar:** Entry on fresh M5 candle

### **Entry Types:**
- **Bullish Setup:** M15 BOS UP → M5 BOS UP → BUY Order
- **Bearish Setup:** M15 BOS DOWN → M5 BOS DOWN → SELL Order

### **Exit Rules:**
- **Stop Loss:** Below/Above M5 Order Block + Buffer
- **Take Profit:** 1:2 Risk Reward Ratio
- **Break Even:** Activated at 100 pips profit
- **Trailing Stop:** Starts at 200 pips, trails by 50 pips

---

## 🛡️ **Risk Management**

### **Position Sizing:**
```
Lot Size = (Account Balance × Risk%) ÷ (SL Distance × Tick Value)
```

### **Risk Controls:**
- **Per Trade Risk:** 1% of account balance (adjustable)
- **Daily Limit:** Maximum 2 trades per day per symbol
- **Session Filter:** Only trade during London/NY sessions
- **SL Distance:** Calculated from M5 Order Block
- **Maximum Lot:** Broker's maximum lot size limit

### **Trade Management:**
- **Break Even:** Move SL to entry at 100 pips profit
- **Trailing Stop:** Trail SL 50 pips behind price after 200 pips profit
- **Partial Close:** Not implemented (can be added)

---

## 📈 **Performance Monitoring**

### **Statistics Panel (Top-Left Corner):**
```
ICT EA Statistics
─────────────────
Total Trades: X
Win Rate: XX.X%
Wins: X | Loss: X
Avg Win: $XX.XX
Avg Loss: $XX.XX
Profit Factor: X.XX
Max DD: XX.XX%
Risk: X.X% per trade
```

### **Key Metrics:**
- **Win Rate:** Percentage of profitable trades
- **Profit Factor:** Gross Profit ÷ Gross Loss
- **Max Drawdown:** Largest peak-to-trough decline
- **Average Win/Loss:** Mean profit/loss per trade

### **Visual Elements:**
- **🟡 M15 Sweep:** Yellow/Orange arrows
- **🟢 M15 BOS:** Green/Red trend lines
- **🟤 M15 OB:** Maroon/Dark Green rectangles
- **🟨 M5 Sweep:** Gold/Orange-Red arrows
- **🔴 M5 OB:** Dark Red/Forest Green rectangles

---

## 🔧 **Troubleshooting**

### **Common Issues:**

#### **1. No Trades Being Placed**
**Symptoms:** EA running but no orders
**Solutions:**
- Check session times match broker timezone
- Verify AutoTrading is enabled
- Ensure sufficient account balance
- Check if daily trade limit reached

#### **2. Wrong Entry Direction**
**Symptoms:** Trades opposite to expected direction
**Solutions:**
- Verify M15 and M5 BOS alignment
- Check sweep direction matches BOS
- Review Order Block identification

#### **3. Large Stop Losses**
**Symptoms:** SL distance too wide
**Solutions:**
- Reduce `OB_Buffer_Points`
- Check M5 Order Block quality
- Verify price action setup

#### **4. Statistics Not Showing**
**Symptoms:** No stats panel visible
**Solutions:**
- Set `ShowStats = true`
- Restart EA
- Check chart space availability

### **Debug Information:**
Monitor Expert tab for debug messages:
```
[M15 FILTER] PASSED - BOS:UP OB Zone:XXXX-XXXX Price in OB: YES
[M5 ENTRY] BUY Signal - M5 BOS + OB + Sweep confirmed
[TRADE] BUY order placed - Entry:XXXX SL:XXXX TP:XXXX
```

---

## 💡 **Best Practices**

### **Recommended Settings:**
- **Timeframe:** Attach to M5 chart (EA handles M15 analysis)
- **Symbols:** Major forex pairs (EURUSD, GBPUSD, USDJPY, etc.)
- **Risk:** Start with 0.5-1% per trade
- **Sessions:** Focus on London/NY overlap (high volatility)

### **Optimization Tips:**
1. **Backtest First:** Test on historical data before live trading
2. **Demo Account:** Run on demo for 1-2 weeks minimum
3. **Small Risk:** Start with minimal risk percentage
4. **Monitor Performance:** Check statistics regularly
5. **Market Conditions:** Perform better in trending markets

### **Do's and Don'ts:**

#### **✅ Do's:**
- Monitor during active sessions
- Keep risk per trade low (≤2%)
- Use on major forex pairs
- Regular performance review
- Maintain stable internet connection

#### **❌ Don'ts:**
- Don't overtrade (respect daily limits)
- Don't ignore session filters
- Don't use on exotic pairs initially
- Don't modify trades manually
- Don't run during major news events

---

## 📞 **Support & Updates**

### **Version History:**
- **v2.00:** Multi-timeframe implementation
- **v1.00:** Initial ICT concepts

### **Future Enhancements:**
- Fair Value Gap (FVG) detection
- News filter integration
- Multi-symbol support
- Advanced statistics
- Mobile notifications

---

## ⚖️ **Disclaimer**

**Risk Warning:** Trading forex involves substantial risk of loss and is not suitable for all investors. Past performance does not guarantee future results. This EA is provided for educational purposes. Always test thoroughly before live trading.

**No Guarantee:** The developers make no warranty regarding the EA's performance. Users trade at their own risk and should never risk more than they can afford to lose.

---

## 📧 **Contact Information**

For technical support or questions about this EA, please refer to the documentation or consult with your trading mentor.

**Remember:** Successful trading requires proper risk management, patience, and continuous learning. This EA is a tool to assist your trading, not a guarantee of profits.

---

*© 2024 ICT Multi-Timeframe Expert Advisor - All Rights Reserved* 