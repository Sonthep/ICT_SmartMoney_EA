#ifndef __SESSION_UTILS_MQH__
#define __SESSION_UTILS_MQH__

#include <ChartObjects\ChartObjectsTxtControls.mqh>

bool InKillzone(string session, int gmtOffset, string symbol) {
    string times[];
    StringSplit(session, '-', times);
    if(ArraySize(times) != 2) return false;
    datetime now = TimeCurrent() + gmtOffset * 3600;
    string today = TimeToString(iTime(symbol, PERIOD_D1, 0), TIME_DATE);
    datetime start = StringToTime(today + " " + times[0]);
    datetime end   = StringToTime(today + " " + times[1]);
    return (now >= start && now <= end);
}

bool InAnySession(string session1, string session2, int gmtOffset, string symbol) {
    return InKillzone(session1, gmtOffset, symbol) || InKillzone(session2, gmtOffset, symbol);
}

void DrawSessionBox(string name, string session, color clr, string labelText) {
    string times[];
    StringSplit(session, '-', times);
    if(ArraySize(times) != 2) return;
    datetime today = iTime(_Symbol, PERIOD_D1, 0);
    datetime start = StringToTime(TimeToString(today, TIME_DATE) + " " + times[0]);
    datetime end   = StringToTime(TimeToString(today, TIME_DATE) + " " + times[1]);
    if (end < start) end += 86400;
    double high = iHigh(_Symbol, PERIOD_D1, 0);
    double low  = iLow(_Symbol, PERIOD_D1, 0);
    string labelName = name + "_label";
    bool inSession = (TimeCurrent() >= start && TimeCurrent() <= end);
    if (inSession) {
        if(ObjectFind(0, name) == -1)
            ObjectCreate(0, name, OBJ_RECTANGLE, 0, start, high, end, low);
        else {
            ObjectMove(0, name, 0, start, high);
            ObjectMove(0, name, 1, end, low);
        }
        ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
        ObjectSetInteger(0, name, OBJPROP_BACK, true);
        if(ObjectFind(0, labelName) == -1)
            ObjectCreate(0, labelName, OBJ_TEXT, 0, start, high);
        else
            ObjectMove(0, labelName, 0, start, high);
        ObjectSetString(0, labelName, OBJPROP_TEXT, labelText + " Session");
        ObjectSetInteger(0, labelName, OBJPROP_COLOR, clr);
    } else {
        if(ObjectFind(0, name) != -1)
            ObjectDelete(0, name);
        if(ObjectFind(0, labelName) != -1)
            ObjectDelete(0, labelName);
    }
}

void DrawSessionText(string name, string session, color clr, string labelText) {
    string times[];
    StringSplit(session, '-', times);
    if(ArraySize(times) != 2) return;
    datetime today = iTime(_Symbol, PERIOD_D1, 0);
    datetime start = StringToTime(TimeToString(today, TIME_DATE) + " " + times[0]);
    datetime end   = StringToTime(TimeToString(today, TIME_DATE) + " " + times[1]);
    if (end < start) end += 86400;
    string labelName = name + "_session_text";
    bool inSession = (TimeCurrent() >= start && TimeCurrent() <= end);
    if (inSession) {
        if(ObjectFind(0, labelName) == -1)
            ObjectCreate(0, labelName, OBJ_LABEL, 0, 0, 0);
        ObjectSetInteger(0, labelName, OBJPROP_CORNER, 0);
        ObjectSetInteger(0, labelName, OBJPROP_XDISTANCE, 20);
        ObjectSetInteger(0, labelName, OBJPROP_YDISTANCE, 20 + (name == "NYKZ" ? 20 : 0));
        ObjectSetString(0, labelName, OBJPROP_TEXT, labelText + " Session Active");
        ObjectSetInteger(0, labelName, OBJPROP_COLOR, clr);
        ObjectSetInteger(0, labelName, OBJPROP_FONTSIZE, 14);
    } else {
        if(ObjectFind(0, labelName) != -1)
            ObjectDelete(0, labelName);
    }
}

#endif // __SESSION_UTILS_MQH__ 