#ifndef __DRAW_UTILS_MQH__
#define __DRAW_UTILS_MQH__

void DrawSweep(string name, datetime time, double price, color clr, int code) {
    if(ObjectFind(0, name) == -1)
        ObjectCreate(0, name, OBJ_ARROW, 0, time, price);
    ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
    ObjectSetInteger(0, name, OBJPROP_ARROWCODE, code);
    ObjectSetInteger(0, name, OBJPROP_WIDTH, 2);
}

void DrawBOS(string name, datetime time1, double price1, datetime time2, double price2, color clr) {
    if(ObjectFind(0, name) == -1)
        ObjectCreate(0, name, OBJ_TREND, 0, time1, price1, time2, price2);
    ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
    ObjectSetInteger(0, name, OBJPROP_WIDTH, 2);
}

void DrawOrderBlock(string name, datetime time1, datetime time2, double priceHigh, double priceLow, color clr) {
    if(ObjectFind(0, name) == -1)
        ObjectCreate(0, name, OBJ_RECTANGLE, 0, time1, priceHigh, time2, priceLow);
    ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
    ObjectSetInteger(0, name, OBJPROP_BACK, true);
}

#endif // __DRAW_UTILS_MQH__ 