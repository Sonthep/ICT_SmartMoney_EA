# ICT Smart Money EA v4.0 - Professional Trading System

## 🚀 Overview

ICT Smart Money EA v4.0 เป็น Expert Advisor ระดับมืออาชีพที่ออกแบบมาเพื่อเทรด Forex โดยใช้หลักการ Smart Money Concepts (SMC) ของ ICT (Inner Circle Trader) ระบบนี้ถูกพัฒนาเพื่อเติบโตบัญชีขนาดเล็กจาก $100 เป็น $1000 ด้วยการจัดการความเสี่ยงที่เข้มงวดและการคัดกรองสัญญาณคุณภาพสูง

## ✨ Key Features

### 🎯 Core Strategy Components
- **Multi-Timeframe Analysis**: วิเคราะห์ M15 สำหรับ context และ M5 สำหรับ entry
- **Order Block Detection**: ตรวจจับ Order Block คุณภาพสูงด้วยการวิเคราะห์ body ratio และ age
- **Break of Structure (BOS)**: ระบุการเปลี่ยนแปลงโครงสร้างตลาดด้วยความแม่นยำ
- **Liquidity Sweep Detection**: ตรวจจับการกวาด liquidity พร้อม rejection confirmation
- **Fair Value Gap (FVG)**: ระบุและวิเคราะห์ช่องว่างราคาสำหรับ confluence

### 🧠 Advanced Confidence Scoring (0-100 Points)
- **BOS Strength** (20 points): ความแข็งแกร่งของการทำลายโครงสร้าง
- **Sweep Quality** (15 points): คุณภาพการกวาด liquidity
- **FVG Presence** (15 points): การมีอยู่ของ Fair Value Gap
- **Order Block Quality** (20 points): คุณภาพของ Order Block
- **Timing Score** (10 points): การเข้าสู่ Killzone ที่เหมาะสม
- **Multi-timeframe Confluence** (10 points): ความสอดคล้องระหว่าง timeframe
- **Distance Score** (10 points): ระยะห่างจาก Order Block ก่อนหน้า

### ⏰ Killzone Management
- **London Killzone**: 08:00-10:30 GMT (เวลาทองสำหรับการเทรด)
- **NY Killzone**: 13:00-16:00 GMT (เซสชันที่มี volatility สูง)
- **Session Quality Scoring**: คะแนนคุณภาพของเวลาการเทรด
- **Timezone Offset Support**: รองรับการปรับเวลาตาม broker

### 💰 Risk Management System
- **Dynamic Lot Sizing**: คำนวณขนาด lot ตามเปอร์เซ็นต์ความเสี่ยง
- **Confidence-Adjusted Position Size**: ปรับขนาดตำแหน่งตามคะแนนความเชื่อมั่น
- **Multiple RR Ratios**: 1:2 สำหรับสัญญาณปกติ, 1:1.5 สำหรับความเชื่อมั่นสูง
- **Daily Trade Limits**: จำกัด 2 เทรดต่อวัน (อนุญาตเทรดที่ 3 หากคะแนน ≥90)
- **Margin Safety Checks**: ตรวจสอบ margin ก่อนเปิดตำแหน่ง

### 📊 Trade Management
- **Break-Even System**: ย้าย SL ไป break-even เมื่อกำไรถึงเป้า
- **Trailing Stop**: ติดตามกำไรด้วย trailing stop แบบ dynamic
- **Position Monitoring**: ติดตามและจัดการตำแหน่งอัตโนมัติ
- **Performance Tracking**: บันทึกสถิติการเทรดรายวัน

### 🎨 Visual Dashboard
- **Real-time Information**: แสดงข้อมูลสถานะการเทรดแบบ real-time
- **Session Status**: สถานะ Killzone ปัจจุบัน
- **Daily Statistics**: สถิติการเทรดรายวัน (P/L, Win Rate, จำนวนเทรด)
- **Signal Information**: ข้อมูลสัญญาณปัจจุบันและคะแนนความเชื่อมั่น
- **Chart Visualization**: แสดง Order Block, FVG, และ BOS บนชาร์ต

## 📁 File Structure

```
ICT_SmartMoney_EA_v4/
├── ICT_SmartMoney_EA_v4.mq5      # Main EA file
├── Structures.mqh                # Common data structures
├── ConfidenceScoring.mqh         # Confidence scoring system
├── OB_BOS_Detection.mqh          # Order Block & BOS detection
├── LiquiditySweep.mqh           # Liquidity sweep & FVG detection
├── KillzoneManager.mqh          # Session management
├── RiskManager_v2.mqh           # Risk management system
├── TradeManager_v2.mqh          # Trade management
├── Dashboard.mqh                # Visual dashboard
├── Utils.mqh                    # Utility functions
└── README_ICT_SmartMoney_EA_v4.md # This documentation
```

## ⚙️ Installation & Setup

### 1. Installation
1. คัดลอกไฟล์ทั้งหมดไปยัง folder `MQL5/Experts/` ใน MetaTrader 5
2. Compile EA ใน MetaEditor (F7)
3. Restart MetaTrader 5
4. ลาก EA ไปยังชาร์ตที่ต้องการ

### 2. Recommended Settings

#### Core Strategy Settings
```
Risk per trade (%): 2.0
Risk:Reward ratio (1:X): 2.0
Alternative RR for high confidence: 1.5
Minimum confidence score: 85
High confidence threshold: 90
```

#### ICT Detection Settings
```
Swing High/Low lookback: 5
BOS lookback M5: 20
BOS lookback M15: 30
Order Block search range: 15
SL buffer points: 30
Require Fair Value Gap: true
```

#### Killzone Settings
```
London Killzone: true (08:00-10:30 GMT)
NY Killzone: true (13:00-16:00 GMT)
Broker timezone offset from GMT: 0
```

#### Trade Management
```
Max trades per day: 2
Allow 3rd trade if score ≥ 90: true
Enable break-even: true
Enable trailing stop: true
```

### 3. Recommended Symbols
- **Major Pairs**: EURUSD, GBPUSD, USDJPY, USDCHF
- **Commodity Currencies**: AUDUSD, NZDUSD, USDCAD
- **Cross Pairs**: EURJPY, GBPJPY, EURGBP

### 4. Recommended Timeframes
- **Chart Timeframe**: M5 (สำหรับการติดตาม)
- **Analysis**: M15 (context) + M5 (entry)

## 📈 Strategy Logic

### Signal Generation Process
1. **M15 Context Analysis**: ตรวจสอบ BOS และ Order Block บน M15
2. **M5 Entry Confirmation**: ยืนยันสัญญาณบน M5 ให้สอดคล้องกับ M15
3. **Liquidity Sweep Detection**: ตรวจจับการกวาด liquidity
4. **FVG Confirmation**: ยืนยันการมี Fair Value Gap (ถ้าเปิดใช้งาน)
5. **Confidence Scoring**: คำนวณคะแนนความเชื่อมั่น (0-100)
6. **Killzone Validation**: ตรวจสอบว่าอยู่ในช่วงเวลาที่เหมาะสม
7. **Risk Calculation**: คำนวณขนาด lot และ SL/TP
8. **Trade Execution**: เปิดตำแหน่งหากผ่านเกณฑ์ทั้งหมด

### Entry Conditions
- ✅ BOS detected on both M15 and M5
- ✅ Fresh Order Block identified
- ✅ Liquidity sweep confirmed with rejection
- ✅ FVG present (if required)
- ✅ Confidence score ≥ 85
- ✅ Within London or NY Killzone
- ✅ Daily trade limit not exceeded
- ✅ No existing position/order

### Exit Conditions
- 🎯 Take Profit hit (1:1.5 or 1:2 RR)
- 🛑 Stop Loss hit
- 🔄 Break-even triggered
- 📈 Trailing stop activated

## 📊 Performance Optimization

### Confidence Score Optimization
- **Score ≥ 90**: ใช้ RR 1:1.5, อนุญาตเทรดที่ 3
- **Score 85-89**: ใช้ RR 1:2, เทรดปกติ
- **Score < 85**: ไม่เทรด

### Risk Management Rules
- **Maximum Risk**: 2% ต่อเทรด
- **Daily Risk Limit**: 6% (3x single trade risk)
- **Position Size**: ปรับตามความเชื่อมั่น (50%-150% ของ base size)
- **Margin Safety**: ใช้เพียง 80% ของ free margin

### Trade Management Rules
- **Break-Even**: เมื่อกำไร ≥ 20 pips, ย้าย SL ไป +5 pips
- **Trailing Start**: เมื่อกำไร ≥ 30 pips
- **Trailing Step**: 10 pips
- **Trailing Distance**: 15 pips

## 🔧 Troubleshooting

### Common Issues
1. **EA ไม่เทรด**: ตรวจสอบ Killzone settings และ confidence threshold
2. **Lot size ผิดปกติ**: ตรวจสอบ account balance และ risk percentage
3. **Dashboard ไม่แสดง**: เปิดใช้งาน "Show dashboard" ใน settings
4. **สัญญาณไม่ถูกต้อง**: ตรวจสอบ timeframe และ symbol compatibility

### Optimization Tips
1. **Backtest**: ทดสอบย้อนหลังก่อนใช้งานจริง
2. **Demo Trading**: ทดสอบบน demo account ก่อน
3. **Parameter Tuning**: ปรับ confidence threshold ตามผลการทดสอบ
4. **Symbol Selection**: เลือก symbol ที่มี spread ต่ำและ volatility เหมาะสม

## 📞 Support & Updates

### Version History
- **v4.0**: Complete modular system with advanced confidence scoring
- **v3.x**: Enhanced multi-timeframe analysis
- **v2.x**: Basic ICT concepts implementation
- **v1.x**: Initial release

### Future Updates
- [ ] Additional timeframe support (H1, H4)
- [ ] News filter integration
- [ ] Advanced money management
- [ ] Mobile notifications
- [ ] Strategy optimization tools

## ⚠️ Disclaimer

การเทรด Forex มีความเสี่ยงสูง EA นี้เป็นเครื่องมือช่วยในการเทรดเท่านั้น ผู้ใช้ควรมีความรู้พื้นฐานเกี่ยวกับ Smart Money Concepts และทดสอบบน demo account ก่อนใช้งานจริง ผู้พัฒนาไม่รับผิดชอบต่อความสูญเสียที่อาจเกิดขึ้น

---

**© 2024 ICT Smart Money EA v4.0 - Professional Trading System** 