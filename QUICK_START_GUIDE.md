# 🚀 ICT Smart Money EA v4.0 - Quick Start Guide

## ⚡ 5-Minute Setup

### 1. Installation (2 minutes)
1. **Download**: Copy all `.mq5` and `.mqh` files to your `MQL5/Experts/` folder
2. **Compile**: Open MetaEditor → Press F7 → Compile `ICT_SmartMoney_EA_v4.mq5`
3. **Restart**: Close and reopen MetaTrader 5

### 2. Basic Setup (2 minutes)
1. **Chart**: Open M5 chart of EURUSD or GBPUSD
2. **Attach EA**: Drag EA from Navigator to chart
3. **Settings**: Use default settings for first test
4. **Enable**: Check "Allow automated trading" and click OK

### 3. Verification (1 minute)
- ✅ Dashboard appears on chart (top-left corner)
- ✅ "ICT Smart Money EA v4.0 Initializing" in Expert tab
- ✅ No error messages in Journal

---

## 🎯 Recommended First Settings

### For Small Account ($100-$500)
```
Risk per trade: 1.5%
Min confidence score: 90
Max trades per day: 1
London Killzone: ✅
NY Killzone: ✅
Show dashboard: ✅
```

### For Demo Testing
```
Risk per trade: 2.0%
Min confidence score: 85
Max trades per day: 2
All visual elements: ✅
```

---

## 📊 What to Expect

### First Hour
- EA scans for signals
- Dashboard shows "Scanning..." status
- No trades until high-quality setup appears

### First Day
- 0-2 trades maximum (by design)
- Trades only during London (8-10:30 GMT) or NY (13-16 GMT)
- Each trade risks only 1.5-2% of account

### First Week
- 3-10 total trades
- Win rate should be 60%+
- Gradual account growth

---

## 🔧 Quick Troubleshooting

| Problem | Solution |
|---------|----------|
| EA not trading | Check if in London/NY killzone hours |
| Dashboard missing | Enable "Show dashboard" in settings |
| Wrong lot size | Verify account balance and risk % |
| No signals | Normal - EA is very selective |

---

## ⚠️ Important Notes

1. **Demo First**: Always test on demo account for 1-2 weeks
2. **Small Risk**: Start with 1-1.5% risk per trade
3. **Patience**: EA trades 1-2 high-quality signals per day only
4. **Monitoring**: Check dashboard for signal confidence scores
5. **Timezone**: Adjust timezone offset if needed

---

## 📈 Success Metrics

### Daily
- Max 2 trades per day
- Each trade: 1.5-2% risk
- Confidence score: 85+ points

### Weekly
- 5-10 trades total
- Win rate: 60%+
- Weekly growth: 2-5%

### Monthly
- 20-40 trades total
- Profit factor: 1.5+
- Monthly growth: 8-15%

---

## 🆘 Need Help?

1. **Check README**: Full documentation in `README_ICT_SmartMoney_EA_v4.md`
2. **Settings Template**: Use `EA_Settings_Template.set` for optimized parameters
3. **Logs**: Check Expert and Journal tabs for error messages
4. **Demo Test**: Always test thoroughly before live trading

---

**🎯 Goal: Grow $100 → $1000 with disciplined risk management and high-quality ICT signals**

*Remember: This EA is designed for quality over quantity. Patience and proper risk management are key to success.* 